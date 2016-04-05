//
//  Study.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/27/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper;

class Study : ReclineObject {

    var studyId = Constants.defaultStudyId;
    var phoneNumber: String = "";
    var studySettings: StudySettings?;
    var patientId: String?;
    var participantConsented: Bool = false;

    init(phoneNumber: String, patientId: String, studySettings: StudySettings, studyId: String = Constants.defaultStudyId) {
        super.init();
        self.phoneNumber = phoneNumber;
        self.studySettings = studySettings;
        self.studyId = studyId;
        self.patientId = patientId;
    }

    required init?(_ map: Map) {
        super.init(map);

    }

    // Mappable
    override func mapping(map: Map) {
        super.mapping(map);
        phoneNumber     <- map["phoneNumber"];
        studySettings   <- map["studySettings"];
        studyId   <- map["studyId"];
        patientId <- map["patientId"];
        participantConsented <- map["participantConsented"];
    }

}