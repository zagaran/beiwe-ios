//
//  OnboardingManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit

class OnboardingManager : NSObject, ORKTaskViewControllerDelegate {

    var retainSelf: AnyObject?;
    var onboardingViewController: ORKTaskViewController!;

    var WelcomeStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: "WelcomeStep")
        instructionStep.image = UIImage(named: "AppIcon60x60")
        instructionStep.title = "Welcome!";
        instructionStep.text = "This is ResearchKit style consent form.  We are using it for onboarding/registration/consent.  We could also have custom content before this point (or intermixed)";
        return instructionStep;
    }

    var SecondStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: "SecondStep")
        instructionStep.title = "Blah Blah page 2!";
        instructionStep.text = "Before registration, the learn more buttons can display custom modal content.  After the point of registration, when we move to the consent form, the learn more buttons trigger a built-in display of textual content (configurable)";
        return instructionStep;
    }

    var PreRegisterStep: ORKStep {
        let instructionStep = ORKInstructionStep(identifier: "PreRegisterStep")
        instructionStep.title = "Register for study";
        instructionStep.text = "Please have your registration user id and password handy.  It should have been provided to you by your clinician.";
        return instructionStep;
    }


    override init() {
        super.init();
        var steps = [ORKStep]();

        steps += [WelcomeStep];
        steps += [SecondStep];
        steps += [PreRegisterStep];
        steps += [ORKWaitStep(identifier: "WaitForRegister")];


        let task = ORKOrderedTask(identifier: "OnboardingTask", steps: steps)
        onboardingViewController = ORKTaskViewController(task: task, taskRunUUID: nil);
        onboardingViewController.showsProgressInNavigationBar = false;
        onboardingViewController.delegate = self;
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
        closeOnboarding();
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


        onboardingViewController.presentViewController(refreshAlert, animated: true, completion: nil)
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
                case "WelcomeStep":
                    stepViewController.cancelButtonItem = nil;
                case "WaitForRegister":
                    let registerViewController = RegisterViewController();
                    registerViewController.dismiss = { [unowned self] didRegister in
                        self.onboardingViewController.dismissViewControllerAnimated(true, completion: nil);
                        if (!didRegister) {
                            self.onboardingViewController.goBackward();
                        } else {
                            // They did register, so if we close this onboarding, it should restart up
                            // with the consent form.
                            self.closeOnboarding();
                        }

                    }
                    onboardingViewController.presentViewController(registerViewController, animated: true, completion: nil)
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