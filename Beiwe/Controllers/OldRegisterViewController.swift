//
//  RegisterViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/21/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import UIKit

class OldRegisterViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var userId: UITextField!
    @IBOutlet weak var temporaryPassword: UITextField!
    @IBOutlet weak var phoneNumber: UITextField!
    @IBOutlet weak var newPassword: UITextField!
    @IBOutlet weak var newPasswordConfirm: UITextField!

    var keyboardHeight:CGFloat = 0


    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        userId.delegate = self;
        temporaryPassword.delegate = self;
        phoneNumber.delegate = self;
        newPassword.delegate = self;
        newPasswordConfirm.delegate = self;


    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func register(sender: AnyObject) {
        print("Register.");
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        return true;
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
