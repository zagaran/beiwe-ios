//
//  SurveyCell.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/21/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation


class SurveyCell: UITableViewCell {
    var activeSurvey: ActiveSurvey?

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var newLabel: UILabel!

    func configure(activeSurvey: ActiveSurvey) {
        self.activeSurvey = activeSurvey


        var desc: String;
        if let surveyType = self.activeSurvey?.survey?.surveyType, surveyType == .AudioSurvey {
            desc = NSLocalizedString("survey_type_audio", comment: "");
        } else {
            desc = NSLocalizedString("survey_type_tracking", comment: "");
        }
        descriptionLabel.text = desc;
        if(self.activeSurvey?.survey?.alwaysAvailable ?? false){
            newLabel.text = NSLocalizedString("survey_status_available", comment: "");
        }
        else{
            newLabel.text = (self.activeSurvey?.bwAnswers.count ?? 0 > 0) ? NSLocalizedString("survey_status_incomplete", comment: "") : NSLocalizedString("survey_status_new", comment: "");
        }
        backgroundColor = UIColor.clear;
        //selectionStyle = UITableViewCellSelectionStyle.None;
        let bgColorView = UIView()
        bgColorView.backgroundColor = AppColors.highlightColor
        selectedBackgroundView = bgColorView
        isSelected = false;
    }
}
