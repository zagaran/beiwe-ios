//
//  BWORKTaskViewController.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/15/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit


class BWORKTaskViewController : ORKTaskViewController {
    var displayDiscard = true;

    @objc override func presentCancelOptions(saveable: Bool, sender: UIBarButtonItem?) {
        super.presentCancelOptions(displayDiscard ? saveable : false, sender: sender);
    }
}