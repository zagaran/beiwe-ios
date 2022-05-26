//
//  MessageViewController.swift
//  Beiwe
//
//  Created by Josh Zagorsky on 5/26/22.
//  Copyright © 2022 Harvard University. All rights reserved.
//

import UIKit


class MessageViewController: UIViewController {
    var message: String!

    @IBOutlet weak var messageContent: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        messageContent.text = message
    }
}
