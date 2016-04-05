//
//  OnboardingManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit

class ConsentManager : NSObject, ORKTaskViewControllerDelegate {

    var retainSelf: AnyObject?;
    var consentViewController: ORKTaskViewController!;
    var consentDocument: ORKConsentDocument!;

    var RegisteredStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: "RegisteredStep")
        instructionStep.image = UIImage(named: "AppIcon60x60")
        instructionStep.title = "Perfect!";
        instructionStep.text = "All set with the registration.  Now we just need to take care of some permissions and legalese";
        return instructionStep;
    }

    var PermissionsStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: "PermissionsStep")
        instructionStep.title = "Permissions";
        instructionStep.text = "Now would be a good time to prompt for location permissions, etc";
        return instructionStep;
    }


    override init() {
        super.init();
        var steps = [ORKStep]();


        consentDocument = ORKConsentDocument()
        consentDocument.title = "Beiwe Consent"

        let overviewSection = ORKConsentSection(type: .Overview);
        overviewSection.summary = "This is the overview of the consent"
        overviewSection.content = "In this study you will be... (Note, not all of the following pages need to be included)"

        let consentSectionTypes: [ORKConsentSectionType] = [
            .DataGathering,
            .Privacy,
            .DataUse,
            .TimeCommitment,
            .StudySurvey,
            .StudyTasks,
            .Withdrawing
        ]


        var consentSections: [ORKConsentSection] = [overviewSection];
        consentSections.appendContentsOf(consentSectionTypes.map { contentSectionType in
            let consentSection = ORKConsentSection(type: contentSectionType)
            consentSection.summary = "Summary for this page"
            consentSection.content = "Additional content for this page."
            return consentSection
        });

        consentDocument.addSignature(ORKConsentSignature(forPersonWithTitle: nil, dateFormatString: nil, identifier: "ConsentDocumentParticipantSignature"))

        consentDocument.sections = consentSections        //TODO: signature
        
        let visualConsentStep = ORKVisualConsentStep(identifier: "VisualConsentStep", document: consentDocument)
        steps += [visualConsentStep]

        //let signature = consentDocument.signatures!.first!

        let reviewConsentStep = ORKConsentReviewStep(identifier: "ConsentReviewStep", signature: nil, inDocument: consentDocument)

        reviewConsentStep.text = "Review Consent!"
        reviewConsentStep.reasonForConsent = "Consent to join study"

        steps += [reviewConsentStep]


        let task = ORKOrderedTask(identifier: "ConsentTask", steps: steps)
        consentViewController = ORKTaskViewController(task: task, taskRunUUID: nil);
        consentViewController.showsProgressInNavigationBar = false;
        consentViewController.delegate = self;
        retainSelf = self;
    }

    func closeOnboarding() {
        AppDelegate.sharedInstance().transitionToCurrentAppState();
        retainSelf = nil;
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
        switch(step.identifier) {
            case "SecondStep":
                return true;
        default: return false;
        }
    }

    func taskViewController(taskViewController: ORKTaskViewController, viewControllerForStep step: ORKStep) -> ORKStepViewController? {
        return nil;
    }

    func taskViewController(taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        print("Step will appear;");
        stepViewController.cancelButtonItem!.title = "Leave Study";

        //stepViewController.continueButtonTitle = "Go!"
    }
}