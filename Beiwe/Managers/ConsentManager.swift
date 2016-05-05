//
//  OnboardingManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit
import PermissionScope


enum StepIds : String {
    case Permission = "PermissionsStep"
    case WaitForPermissions = "WaitForPermissions"
    case WarningStep = "WarningStep"
    case VisualConsent = "VisualConsentStep"
    case ConsentReview = "ConsentReviewStep"
}

class WaitForPermissionsRule : ORKStepNavigationRule {
    let nextTask: ((ORKTaskResult) -> String)
    init(nextTask: ((taskResult: ORKTaskResult) -> String)) {
        self.nextTask = nextTask

        super.init(coder: NSCoder())!
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func identifierForDestinationStepWithTaskResult(taskResult: ORKTaskResult)  -> String {
        return self.nextTask(taskResult)
    }
}

class ConsentManager : NSObject, ORKTaskViewControllerDelegate {

    let pscope = AppDelegate.sharedInstance().pscope;
    var retainSelf: AnyObject?;
    var consentViewController: ORKTaskViewController!;
    var consentDocument: ORKConsentDocument!;

    var PermissionsStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: StepIds.Permission.rawValue)
        instructionStep.title = "Permissions";
        instructionStep.text = "This app requires your access to your location at all times.  It just won't work without it.  We'd also like to notify you when it's time to fill out the next survey";
        return instructionStep;
    }

    var WarningStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: StepIds.WarningStep.rawValue)
        instructionStep.title = "Warning";
        instructionStep.text = "Permission to access your location is required to correctly gather the data required for this study.  To participate in this study we highly recommend you go back and allow this application to access your location.";
        return instructionStep;
    }



    override init() {
        super.init();

        // Set up permissions

        var steps = [ORKStep]();


        if (!hasRequiredPermissions()) {
            steps += [PermissionsStep];
            steps += [ORKWaitStep(identifier: StepIds.WaitForPermissions.rawValue)];
            steps += [WarningStep];
        }

        consentDocument = ORKConsentDocument()
        consentDocument.title = "Beiwe Consent"

        let studyConsentSections = StudyManager.sharedInstance.currentStudy?.studySettings?.consentSections ?? [:];


        let overviewSection = ORKConsentSection(type: .Overview);
        if let welcomeStudySection = studyConsentSections["welcome"] where !welcomeStudySection.text.isEmpty {
            overviewSection.summary = welcomeStudySection.text
            if (!welcomeStudySection.more.isEmpty) {
                overviewSection.content = welcomeStudySection.more
            }
        } else {
            overviewSection.summary = "Welcome to the study"
        }

        let consentSectionTypes: [(ORKConsentSectionType, String)] = [
            (.DataGathering, "data_gathering"),
            (.Privacy, "privacy"),
            (.DataUse, "data_use"),
            (.TimeCommitment, "time_commitment"),
            (.StudySurvey, "study_survey"),
            (.StudyTasks, "study_tasks"),
            (.Withdrawing, "withdrawing")
        ]


        var hasAdditionalConsent = false;
        var consentSections: [ORKConsentSection] = [overviewSection];
        for (contentSectionType, bwType) in consentSectionTypes {
            if let bwSection = studyConsentSections[bwType] where !bwSection.text.isEmpty {
                hasAdditionalConsent = true;
                let consentSection = ORKConsentSection(type: contentSectionType)
                consentSection.summary = bwSection.text
                if (!bwSection.more.isEmpty) {
                    consentSection.content = bwSection.more
                }
                consentSections.append(consentSection);
            }
        }

        consentDocument.addSignature(ORKConsentSignature(forPersonWithTitle: nil, dateFormatString: nil, identifier: "ConsentDocumentParticipantSignature"))

        consentDocument.sections = consentSections        //TODO: signature
        
        let visualConsentStep = ORKVisualConsentStep(identifier: StepIds.VisualConsent.rawValue, document: consentDocument)
        steps += [visualConsentStep]

        //let signature = consentDocument.signatures!.first!

        if (hasAdditionalConsent) {
            let reviewConsentStep = ORKConsentReviewStep(identifier: StepIds.ConsentReview.rawValue, signature: nil, inDocument: consentDocument)

            reviewConsentStep.text = "Review Consent"
            reviewConsentStep.reasonForConsent = "Consent to join study"

            steps += [reviewConsentStep]
        }

        let task = ORKNavigableOrderedTask(identifier: "ConsentTask", steps: steps)
        //let waitForPermissionRule = WaitForPermissionsRule(coder: NSCoder())
        //task.setNavigationRule(waitForPermissionRule!, forTriggerStepIdentifier: StepIds.WaitForPermissions.rawValue)
        task.setNavigationRule(WaitForPermissionsRule() { [weak self] taskResult -> String in
            if (self?.pscope.statusLocationAlways() == .Authorized) {
                return StepIds.VisualConsent.rawValue
            } else {
                return StepIds.WarningStep.rawValue
            }

            }, forTriggerStepIdentifier: StepIds.WaitForPermissions.rawValue)
        consentViewController = ORKTaskViewController(task: task, taskRunUUID: nil);
        consentViewController.showsProgressInNavigationBar = false;
        consentViewController.delegate = self;
        retainSelf = self;
    }

    func closeOnboarding() {
        AppDelegate.sharedInstance().transitionToCurrentAppState();
        retainSelf = nil;
    }

    func hasRequiredPermissions() -> Bool {
        return (pscope.statusNotifications() == .Authorized && pscope.statusLocationAlways() == .Authorized);
    }

    /* ORK Delegates */
    func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)
        if (reason == ORKTaskViewControllerFinishReason.Discarded) {
            StudyManager.sharedInstance.leaveStudy().then { _ -> Void in
                self.closeOnboarding();
            }
        } else {
            StudyManager.sharedInstance.setConsented().then { _ -> Void in
                self.closeOnboarding();
            }
        }
        print("Finished.");
    }

    func taskViewController(taskViewController: ORKTaskViewController, didChangeResult result: ORKTaskResult) {

        return;
    }

    func taskViewController(taskViewController: ORKTaskViewController, shouldPresentStep step: ORKStep) -> Bool {
        /*
        if let identifier = StepIds(rawValue: step.identifier) {
            switch(identifier) {
            case .WarningStep:
                if (pscope.statusLocationAlways() == .Authorized) {
                    taskViewController.goForward();
                    return false;
                }
            default: break
            }
        }
        */
        return true;

    }

    func taskViewController(taskViewController: ORKTaskViewController, learnMoreForStep stepViewController: ORKStepViewController) {
        // Present modal...
        let refreshAlert = UIAlertController(title: "Learning more!", message: "You're smart now", preferredStyle: UIAlertControllerStyle.Alert)

        refreshAlert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: { (action: UIAlertAction!) in
            print("Handle Ok logic here")
        }))


        consentViewController.presentViewController(refreshAlert, animated: true, completion: nil)
    }

    func taskViewController(taskViewController: ORKTaskViewController, hasLearnMoreForStep step: ORKStep) -> Bool {
        return false;
    }

    func taskViewController(taskViewController: ORKTaskViewController, viewControllerForStep step: ORKStep) -> ORKStepViewController? {
        return nil;
    }

    func taskViewController(taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        print("Step will appear: \(stepViewController.step?.identifier)");
        stepViewController.cancelButtonItem!.title = "Leave Study";

        if let identifier = StepIds(rawValue: stepViewController.step?.identifier ?? "") {
            switch(identifier) {
            case .WaitForPermissions:
                pscope.show({ finished, results in
                    print("Permissions granted");
                    if (self.hasRequiredPermissions()) {
                        stepViewController.goForward();
                    }
                    }, cancelled: { (results) in
                        print("Permissions cancelled");
                        stepViewController.goForward();
                })
            case .Permission:
                stepViewController.continueButtonTitle = "Permissions";
            case .WarningStep:
                if (pscope.statusLocationAlways() == .Authorized) {
                    stepViewController.goForward();
                } else {
                    stepViewController.continueButtonTitle = "Continue";
                }
            case .VisualConsent:
                if (hasRequiredPermissions()) {
                    stepViewController.backButtonItem = nil;
                }
            default: break;
            }
        }

        //stepViewController.continueButtonTitle = "Go!"
    }
}