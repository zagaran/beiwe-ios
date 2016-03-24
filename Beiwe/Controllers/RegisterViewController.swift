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
import libPhoneNumber_iOS;


class RegisterViewController: FormViewController {

    let autoValidation = false;

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        form +++ Section("Register for Study")
            <<< SVAccountRow("account") {
                $0.title = "User ID:"
                $0.placeholder = "Enter User ID";
                $0.rules = [RequiredRule()]
                $0.autoValidation = autoValidation

            }
            <<< SVPasswordRow("tempPassword") {
                $0.title = "Temporary Password:"
                $0.placeholder = "temp password";
                $0.rules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            <<< SVSimplePhoneRow("phone") {
                $0.title = "Phone:"
                $0.placeholder = "10 digit number";
                $0.rules = [RequiredRule(), PhoneNumberRule()]
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
                $0.title = "Register"
                }
                .onCellSelection {
                    [unowned self] cell, row in
                    if (self.form.validateAll()) {
                        print("Form validates, should register");
                        PKHUD.sharedHUD.dimsBackground = true;
                        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false;
                        HUD.show(.Progress);
                        delay(2.0) {
                            HUD.flash(.LabeledError(title: "Registration failed", subtitle: "Couldn't connect to server"), delay: 1)
                        }
                    } else {
                        print("Bad validation.");
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
