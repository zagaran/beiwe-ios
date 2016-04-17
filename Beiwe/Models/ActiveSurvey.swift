//
//  ActiveSurvey.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/9/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

class ActiveSurvey : Mappable {

    var isComplete: Bool = false;
    var survey: Survey?;
    var expires: NSTimeInterval = 0;
    var received: NSTimeInterval = 0;
    var rkAnswers: NSData?;
    var notification: UILocalNotification?;
    var stepOrder: [Int]?;
    var bwAnswers: [String:String] = [:]

    init(survey: Survey) {
        self.survey = survey;
    }

    required init?(_ map: Map) {

    }

    // Mappable
    func mapping(map: Map) {
        isComplete  <- map["is_complete"];
        survey      <- map["survey"];
        expires     <- map["expires"]
        received    <- map["received"];
        rkAnswers   <- (map["rk_answers"], transformNSData);
        bwAnswers   <- map["bk_answers"]
        notification    <- (map["notification"], transformNotification);
        stepOrder   <- map["stepOrder"];
    }

    func reset() {
        rkAnswers = nil;
        bwAnswers = [:]
        isComplete = false;
        guard let survey = survey else {
            return;
        }

        var steps = [Int](0..<survey.questions.count)
        if (survey.randomize) {
            shuffle(&steps);
        }

        let numQuestions = survey.randomize ? min(survey.questions.count, survey.numberOfRandomQuestions ?? 999) : survey.questions.count;
        if (survey.randomizeWithMemory && stepOrder != nil) {
            // We must have already asked a bunch of questions, otherwise stepOrder would be nil.  Remvoe them
            stepOrder?.removeFirst(min(numQuestions, stepOrder!.count));
            if (stepOrder!.count < numQuestions) {
                stepOrder?.appendContentsOf(steps);
            }
        } else {
            stepOrder = Array(steps.prefix(numQuestions));
        }
    }
}