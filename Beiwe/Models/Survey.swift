//
//  Survey.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/7/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

enum SurveyTypes: String {
    case AudioSurvey = "audio_survey"
    case TrackingSurvey = "tracking_survey"
}

struct Survey : Mappable  {

    var surveyId: String?;
    var surveyType: SurveyTypes?;
    var timings: [[Int]] = [];
    var triggerOnFirstDownload: Bool = false;
    var randomize: Bool = false;
    var numberOfRandomQuestions: Int?;
    var randomizeWithMemory: Bool = false;
    var questions: [GenericSurveyQuestion] = [ ];

    init?(_ map: Map) {

    }

    // Mappable
    mutating func mapping(map: Map) {
        surveyId    <- map["_id"]
        surveyType  <- map["survey_type"]
        timings     <- map["timings"];
        triggerOnFirstDownload  <- map["settings.trigger_on_first_download"]
        randomize   <- map["settings.randomize"]
        numberOfRandomQuestions <- map["settings.number_of_random_questions"]
        randomizeWithMemory     <- map["settings.randomize_with_memory"]
        questions               <- map["content"];
    }
    
}