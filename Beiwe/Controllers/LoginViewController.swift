//
//  LoginViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import PKHUD

class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var loginButton: BWBorderedButton!
    @IBOutlet weak var password: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
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

}
