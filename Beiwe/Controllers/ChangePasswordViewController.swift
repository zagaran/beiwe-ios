//
//  RegisterViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/23/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit
import Eureka
import SwiftValidator
import PKHUD
import PromiseKit

class ChangePasswordViewController: FormViewController {

    let autoValidation = false;
    let db = Recline.shared;
    var isForgotPassword = false;
    var finished: ((changed: Bool) -> Void)?;

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        form +++ Section("Change Password")
            <<< SVPasswordRow("currentPassword") {
                $0.title = isForgotPassword ? "Temporary Password:" : "Current Password:"
                $0.placeholder = $0.title?.lowercaseString;
                $0.rules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("password") {
                $0.title = "New Password:"
                $0.placeholder = "Enter your new password";
                $0.rules = [RequiredRule(), RegexRule(regex: Constants.passwordRequirementRegex, message: Constants.passwordRequirementDescription)]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("confirmPassword") {
                $0.title = "Confirm Password:"
                $0.placeholder = "Confirm your new password";
                $0.rules = [RequiredRule(), MinLengthRule(length: 1)]
                $0.autoValidation = autoValidation
            }
            <<< ButtonRow() {
                $0.title = "Change"
                }
                .onCellSelection {
                    [unowned self] cell, row in
                    if (self.form.validateAll()) {
                        print("Form validates, should register");
                        PKHUD.sharedHUD.dimsBackground = true;
                        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false;
                        HUD.show(.Progress);
                        let formValues = self.form.values();
                        //let newPassword: String? = formValues["password"] as! String?;
                        //let currentPassword: String? = formValues["currentPassword"] as! String?;
                        HUD.flash(.Success, delay: 0.5);
                        if let finished = self.finished {
                            finished(changed: true);
                        } else {
                            self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil);
                        }
                    } else {
                        print("Bad validation.");
                    }
                }
            <<< ButtonRow() {
                $0.title = "Cancel";
                }.onCellSelection { [unowned self] cell, row in
                    if let finished = self.finished {
                        finished(changed: false);
                    } else {
                        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil);
                    }
        }
        let passwordRow: SVPasswordRow? = form.rowByTag("password");
        let confirmRow: SVPasswordRow? = form.rowByTag("confirmPassword");
        confirmRow!.rules = [ConfirmationRule(confirmField: passwordRow!.cell.textField)]



    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
