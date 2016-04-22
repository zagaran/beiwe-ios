//
//  LoginViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import PKHUD
import ResearchKit

class LoginViewController: UIViewController, UITextFieldDelegate, ORKTaskViewControllerDelegate {

    @IBOutlet weak var loginButton: BWBorderedButton!
    @IBOutlet weak var password: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.presentTransparentNavigationBar();

        password.delegate = self
        loginButton.enabled = false;
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tap))
        view.addGestureRecognizer(tapGesture)

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func loginPressed(sender: AnyObject) {
        password.resignFirstResponder();
        PKHUD.sharedHUD.dimsBackground = true;
        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false;

        if let password = password.text where password.characters.count > 0 {
            if (AppDelegate.sharedInstance().checkPasswordAndLogin(password)) {
                HUD.flash(.Success, delay: 0.5);
                AppDelegate.sharedInstance().transitionToCurrentAppState();
            } else {
                HUD.flash(.Error, delay: 1);
            }
        }
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        loginPressed(self);
        textField.resignFirstResponder();
        return true;
    }

    func tap(gesture: UITapGestureRecognizer) {
        password.resignFirstResponder()
    }

    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {

        // Find out what the text field will be after adding the current edit
        if let text = (password.text as NSString?)?.stringByReplacingCharactersInRange(range, withString: string) {
            if !text.isEmpty{//Checking if the input field is not empty
                loginButton.enabled = true //Enabling the button
            } else {
                loginButton.enabled = false //Disabling the button
            }
        }

        // Return true so the text field will be changed
        return true
    }

    func textFieldShouldEndEditing(textField: UITextField) -> Bool {
        return true;
    }

    @IBAction func forgotPassword(sender: AnyObject) {
        var steps = [ORKStep]();

        let instructionStep = ORKInstructionStep(identifier: "forgotpassword")
        instructionStep.title = "Forgot Password";
        instructionStep.text = "To reset your password, please contact your clincians research assistant at " + (StudyManager.sharedInstance.currentStudy?.raPhoneNumber ?? "") + ".  Once you have called and received a temporary password, click on continue to set a new password.  Your patient ID is " + (StudyManager.sharedInstance.currentStudy?.patientId ?? "")
        steps += [instructionStep];
        steps += [ORKWaitStep(identifier: "wait")];

        let task = ORKOrderedTask(identifier: "ForgotPasswordTask", steps: steps)
        let vc = ORKTaskViewController(task: task, taskRunUUID: nil);
        vc.showsProgressInNavigationBar = false;
        vc.delegate = self;
        presentViewController(vc, animated: true, completion: nil);
    }
    
    /*
    @IBAction func leaveStudyPressed(sender: AnyObject) {
        StudyManager.sharedInstance.leaveStudy().then {_ -> Void in
            AppDelegate.sharedInstance().isLoggedIn = false;
            AppDelegate.sharedInstance().transitionToCurrentAppState();
        }
    }
    */
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func callClinician(sender: AnyObject) {
        confirmAndCallClinician();
    }
    /* ORK Delegates */
    func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
        //Handle results with taskViewController.result
        //taskViewController.dismissViewControllerAnimated(true, completion: nil)
        taskViewController.presentingViewController?.dismissViewControllerAnimated(true, completion: nil);
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
    }

    func taskViewController(taskViewController: ORKTaskViewController, hasLearnMoreForStep step: ORKStep) -> Bool {
        return false;
    }

    func taskViewController(taskViewController: ORKTaskViewController, viewControllerForStep step: ORKStep) -> ORKStepViewController? {
        return nil;
    }

    func taskViewController(taskViewController: ORKTaskViewController, stepViewControllerWillAppear stepViewController: ORKStepViewController) {
        print("Step will appear;");
        if let identifier = stepViewController.step?.identifier {
            switch(identifier) {
            case "forgotpassword":
                stepViewController.continueButtonTitle = "Continue";
            case "wait":
                let vc = ChangePasswordViewController();
                vc.isForgotPassword = true;
                vc.finished = { _ in
                    taskViewController.presentingViewController?.dismissViewControllerAnimated(true, completion: nil);
                }
                taskViewController.presentViewController(vc, animated: true, completion: nil);
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
