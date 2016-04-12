//
//  OnboardingManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit

class AudioSurveyPresenter : NSObject, ORKTaskViewControllerDelegate {

    var retainSelf: AnyObject?;
    var taskiewController: ORKTaskViewController!;
    var surveyId: String?;
    var activeSurvey: ActiveSurvey?;
    var survey: Survey?;
    var parent: UIViewController?;


    init(surveyId: String, activeSurvey: ActiveSurvey, survey: Survey) {
        super.init();
        self.surveyId = surveyId;
        self.activeSurvey = activeSurvey;
        self.survey = survey;
    }

    func present(parent: UIViewController) {
        guard  let survey = survey, activeSurvey = activeSurvey, surveyId = surveyId where survey.questions.count > 0 else {
            return;
        }
        self.parent = parent;
        var steps = [ORKStep]();

        let instructionStep = ORKInstructionStep(identifier: "audio");
        instructionStep.title = "Audio Question -- This will be custom, no RK default"
        instructionStep.text = survey.questions[0].prompt
        steps += [instructionStep];

        let finishStep = ORKInstructionStep(identifier: "finished");
        finishStep.title = "Audio Completed";
        finishStep.text = StudyManager.sharedInstance.currentStudy?.studySettings?.submitSurveySuccessText;
        steps += [finishStep];

        let task = ORKOrderedTask(identifier: "SurveyTask", steps: steps)
        let surveyViewController = ORKTaskViewController(task: task, taskRunUUID: nil);
        surveyViewController.showsProgressInNavigationBar = false;
        surveyViewController.delegate = self;

        self.retainSelf = self;
        parent.presentViewController(surveyViewController, animated: true, completion: nil)
        

    }

    func closeSurvey() {
        retainSelf = nil;
        parent?.dismissViewControllerAnimated(true, completion: nil);
    }

    /* ORK Delegates */
    func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)
        closeSurvey();
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


        taskViewController.presentViewController(refreshAlert, animated: true, completion: nil)
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
        if let identifier = stepViewController.step?.identifier {
            switch(identifier) {
            case "audio":
                stepViewController.continueButtonTitle = "Save Audio";
            case "finished":
                activeSurvey?.isComplete = true;
                StudyManager.sharedInstance.updateActiveSurveys(true);
                stepViewController.cancelButtonItem = nil;
                stepViewController.backButtonItem = nil;
            default: break
            }
        }
        /*
        if (stepViewController.step?.identifier == "login") {
            stepViewController.cancelButtonItem = nil;
        }
        */
 
        //stepViewController.continueButtonTitle = "Go!"
    }
}