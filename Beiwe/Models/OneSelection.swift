//
//  OneSelection.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/8/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ObjectMapper

struct OneSelection : Mappable {

    var text: String = "";
    init?(map: Map) {

    }

    // Mappable
    mutating func mapping(map: Map) {
        text <- map["text"];
    }
}
