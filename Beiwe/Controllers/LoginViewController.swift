//
//  LoginViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/4/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import PKHUD

class LoginViewController: UIViewController {

    @IBOutlet weak var password: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func loginPressed(sender: AnyObject) {
        PKHUD.sharedHUD.dimsBackground = true;
        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false;

        if let password = password.text {
            if (AppDelegate.sharedInstance().checkPasswordAndLogin(password)) {
                HUD.flash(.Success, delay: 0.5);
                AppDelegate.sharedInstance().transitionToCurrentAppState();
            } else {
                HUD.flash(.Error, delay: 1);
            }
        }
    }

    @IBAction func leaveStudyPressed(sender: AnyObject) {
        StudyManager.sharedInstance.leaveStudy().then {_ -> Void in
            AppDelegate.sharedInstance().isLoggedIn = false;
            AppDelegate.sharedInstance().transitionToCurrentAppState();
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
