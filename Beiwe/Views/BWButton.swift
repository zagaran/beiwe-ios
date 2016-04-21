//
//  BWButton.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/20/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import UIKit

class BWButton : UIButton {

    let fadeDelay = 0.0;
    override var selected: Bool {
        didSet {
            updateBorderColor();
        }
    }

    override var highlighted: Bool {
        didSet {
            updateBorderColor();
        }
    }

    override var enabled: Bool {
        didSet {
            updateBorderColor();
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        self.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Selected)
        self.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Highlighted)

        self.setTitleColor(UIColor.darkGrayColor(), forState: UIControlState.Disabled)
        self.layer.borderWidth = 1
        self.layer.cornerRadius = 5
        self.layer.masksToBounds = true
        self.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        updateBorderColor();
    }

    func fadeHighlightOrSelectColor() {
        // Ignore if it's a race condition
        if (self.enabled && !(self.highlighted || self.selected)) {
            self.backgroundColor = UIColor.clearColor();
            self.layer.borderColor = UIColor.whiteColor().CGColor;
        }
    }

    func updateBorderColor() {
        if (self.enabled && (self.highlighted || self.selected)) {
            self.backgroundColor = AppColors.highlightColor
            self.layer.borderColor = AppColors.highlightColor.CGColor;
        } else if (self.enabled && !(self.highlighted || self.selected)) {
            if (self.fadeDelay > 0) {
                let delayTime = dispatch_time(DISPATCH_TIME_NOW,
                                              Int64(self.fadeDelay * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    self.fadeHighlightOrSelectColor();
                    }
            } else {
                self.fadeHighlightOrSelectColor();
            }
        } else {
            self.backgroundColor = UIColor.clearColor();
            self.layer.borderColor = UIColor.darkGrayColor().CGColor;
        }
    }

}