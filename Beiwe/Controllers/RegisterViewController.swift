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

class RegisterViewController: FormViewController {

    let autoValidation = false;
    let db = Recline.shared;

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        form +++ Section("Register for Study")
            <<< SVAccountRow("patientId") {
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
                        let formValues = self.form.values();
                        let patientId: String? = formValues["patientId"] as! String?;
                        let phoneNumber: String? = formValues["phone"] as! String?;
                        let newPassword: String? = formValues["password"] as! String?;
                        let tempPassword: String? = formValues["tempPassword"] as! String?;
                        if let patientId = patientId, phoneNumber = phoneNumber, newPassword = newPassword {
                            let registerStudyRequest = RegisterStudyRequest(patientId: patientId, phoneNumber: phoneNumber, newPassword: newPassword)
                            ApiManager.sharedInstance.password = tempPassword ?? "";
                            ApiManager.sharedInstance.patientId = patientId;
                            ApiManager.sharedInstance.makePostRequest(registerStudyRequest).then {
                                (studySettings, _) -> Promise<Study> in
                                print("study settings received");
                                PersistentPasswordManager.sharedInstance.storePassword(newPassword);
                                let study = Study(phoneNumber: phoneNumber, patientId: patientId, studySettings: studySettings);
                                return self.db.save(study);
                            }.then { _ -> Void in
                                HUD.flash(.Success, delay: 1);
                                StudyManager.sharedInstance.loadDefaultStudy();
                            }.error { error -> Void in
                                print("error received from register: \(error)");
                                var delay = 2.0;
                                var err: HUDContentType;
                                switch error {
                                case ApiErrors.FailedStatus(let code):
                                    switch code {
                                    case 403:
                                        err = .LabeledError(title: "Registration failed", subtitle: "Incorrect UserID or Password");
                                    case 405:
                                        err = .Label("UserID already registered on another device.  Please contact your study administrator to unregister any previous devices that may have been used");
                                        delay = 10.0;
                                    default:
                                        err = .LabeledError(title: "Registration failed", subtitle: "Communication error");
                                    }
                                default:
                                    err = .LabeledError(title: "Registration failed", subtitle: "Communication error");
                                }
                                HUD.flash(err, delay: delay)
                            }
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
