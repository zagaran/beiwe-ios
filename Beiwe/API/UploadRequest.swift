//
//  UploadRequest.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/30/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//


import Foundation
import ObjectMapper

struct NullResponse: Mappable {
    init?(_ map: Map) {

    }

    mutating func mapping(map: Map) {
        
    }
}
struct UploadRequest : Mappable, ApiRequest {

    static let apiEndpoint = "/upload"
    typealias ApiReturnType = NullResponse;

    var fileName: String?;
    var fileData: String?;

    init(fileName: String, filePath: String) {
        self.fileName = fileName;
        do {
            self.fileData = try NSString(contentsOfFile: filePath, encoding: NSUTF8StringEncoding) as String;
        } catch {
            print("Error reading file for upload: \(error)");
            fileData = "";
        }
    }

    init?(_ map: Map) {

    }

    // Mappable
    mutating func mapping(map: Map) {
        fileName         <- map["file_name"];
        fileData        <- map["file"]
    }
    
}