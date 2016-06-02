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
    var dismiss: ((didRegister: Bool) -> Void)?;

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        let font = UIFont.systemFontOfSize(13.0);
        SVAccountRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        SVPasswordRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        SVSimplePhoneRow.defaultCellSetup = { cell, row in
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font;
        }
        form +++ Section("Register for Study")
            <<< SVAccountRow("patientId") {
                $0.title = "User ID:"
                $0.placeholder = "User ID";
                $0.rules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("tempPassword") {
                $0.title = "Temporary Password:"
                $0.placeholder = "Temp Password";
                $0.rules = [RequiredRule()]
                $0.autoValidation = autoValidation
            }
            /*
            <<< SVSimplePhoneRow("phone") {
                $0.title = "Phone:"
                $0.placeholder = "Your 10 digit number";
                $0.rules = [RequiredRule(), PhoneNumberRule()]
                $0.autoValidation = autoValidation
            }
            */
            <<< SVPasswordRow("password") {
                $0.title = "New Password:"
                $0.placeholder = "New password";
                $0.rules = [RequiredRule(), RegexRule(regex: Constants.passwordRequirementRegex, message: Constants.passwordRequirementDescription)]
                $0.autoValidation = autoValidation
            }
            <<< SVPasswordRow("confirmPassword") {
                $0.title = "Confirm Password:"
                $0.placeholder = "Confirm Password";
                $0.rules = [RequiredRule(), MinLengthRule(length: 1)]
                $0.autoValidation = autoValidation
            }
            <<< SVSimplePhoneRow("clinicianPhone") {
                $0.title = "Primary Researcher Phone:"
                $0.placeholder = "10 digit number";
                $0.rules = [RequiredRule(), PhoneNumberRule()]
                $0.autoValidation = autoValidation

            }
            <<< SVSimplePhoneRow("raPhone") {
                $0.title = "Research Asst. Phone:"
                $0.placeholder = "10 digit number";
                $0.rules = [RequiredRule(), PhoneNumberRule()]
                $0.autoValidation = autoValidation

            }
            <<< ButtonRow() {
                $0.title = "Register"
                }
                .onCellSelection {
                    [unowned self] cell, row in
                    if (self.form.validateAll()) {
                        PKHUD.sharedHUD.dimsBackground = true;
                        PKHUD.sharedHUD.userInteractionOnUnderlyingViewsEnabled = false;
                        HUD.show(.Progress);
                        let formValues = self.form.values();
                        let patientId: String? = formValues["patientId"] as! String?;
                        //let phoneNumber: String? = formValues["phone"] as! String?;
                        let phoneNumber: String? = "NOT_SUPPLIED"
                        let newPassword: String? = formValues["password"] as! String?;
                        let tempPassword: String? = formValues["tempPassword"] as! String?;
                        let clinicianPhone: String? = formValues["clinicianPhone"] as! String?;
                        let raPhone: String? = formValues["raPhone"] as! String?;
                        if let patientId = patientId, phoneNumber = phoneNumber, newPassword = newPassword, clinicianPhone = clinicianPhone, raPhone = raPhone {
                            let registerStudyRequest = RegisterStudyRequest(patientId: patientId, phoneNumber: phoneNumber, newPassword: newPassword)
                            ApiManager.sharedInstance.password = tempPassword ?? "";
                            ApiManager.sharedInstance.patientId = patientId;
                            ApiManager.sharedInstance.makePostRequest(registerStudyRequest).then {
                                (studySettings, _) -> Promise<Study> in
                                PersistentPasswordManager.sharedInstance.storePassword(newPassword);
                                let study = Study(patientPhone: phoneNumber, patientId: patientId, studySettings: studySettings);
                                study.clinicianPhoneNumber = clinicianPhone
                                study.raPhoneNumber = raPhone
                                if let clientPublicKey = study.studySettings?.clientPublicKey {
                                    do {
                                        try PersistentPasswordManager.sharedInstance.storePublicKeyForStudy(clientPublicKey);
                                    } catch {
                                        log.error("Failed to store RSA key in keychain.");
                                    }
                                } else {
                                    log.error("No public key found.  Can't store");
                                }
                                return StudyManager.sharedInstance.purgeStudies().then {_ in 
                                    return self.db.save(study)
                                }
                            }.then { _ -> Promise<Bool> in
                                HUD.flash(.Success, delay: 1);
                                return StudyManager.sharedInstance.loadDefaultStudy();
                            }.then { _ -> Void in
                                AppDelegate.sharedInstance().isLoggedIn = true;
                                if let dismiss = self.dismiss {
                                    dismiss(didRegister: true);
                                } else {
                                    self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil);
                                }
                            }.error { error -> Void in
                                print("error received from register: \(error)");
                                var delay = 2.0;
                                var err: HUDContentType;
                                switch error {
                                case ApiErrors.FailedStatus(let code):
                                    switch code {
                                    case 403, 401:
                                        err = .LabeledError(title: "Registration failed", subtitle: "Incorrect patient ID or Password");
                                    case 405:
                                        err = .Label("UserID already registered on another device.  Please contact your study administrator to unregister any previous devices that may have been used");
                                        delay = 10.0;
                                    case 400:
                                        err = .Label("This device could not be registered under the provided patient ID.  Please contact your study administrator");
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
            <<< ButtonRow() {
                $0.title = "Cancel";
                }.onCellSelection { [unowned self] cell, row in
                    if let dismiss = self.dismiss {
                        dismiss(didRegister: false);
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
