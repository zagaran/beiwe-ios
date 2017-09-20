//
//  GetSurveysRequest.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/7/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

struct GetSurveysRequest : Mappable, ApiRequest {

    static let apiEndpoint = "/download_surveys/ios/"
    typealias ApiReturnType = Survey;


    init() {
    }

    init?(map: Map) {

    }

    // Mappable
    mutating func mapping(map: Map) {
    }

}
