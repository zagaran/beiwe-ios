//
//  MessageCell.swift
//  Beiwe
//
//  Created by Josh Zagorsky on 5/26/22.
//  Copyright © 2022 Harvard University. All rights reserved.
//

import Foundation


class MessageCell: UITableViewCell {
    var message: String?

    @IBOutlet weak var descriptionLabel: UILabel!
    
    func configure(message: String) {
//        descriptionLabel.text = "Message"
        descriptionLabel.text = message

        backgroundColor = UIColor.clear;
        let bgColorView = UIView()
        bgColorView.backgroundColor = AppColors.highlightColor
        selectedBackgroundView = bgColorView
        isSelected = false;
    }
}

