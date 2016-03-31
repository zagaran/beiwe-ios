//
//  ApiManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/24/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import PromiseKit;
import Alamofire;
import ObjectMapper;



protocol ApiRequest {
    associatedtype ApiReturnType : Mappable;
    static var apiEndpoint: String { get };
}

enum ApiErrors: ErrorType {
    case FailedStatus(code: Int)
    case FileNotFound
}

class ApiManager {
    static let sharedInstance = ApiManager();
    private let baseApiUrl = Configuration.sharedInstance.settings["server-url"] as! String;
    private var deviceId = PersistentAppUUID.sharedInstance.uuid;

    private var hashedPassword = "";

    var password: String {
        set {
            hashedPassword = Crypto.sharedInstance.sha256Base64URL(newValue);
            print("Hashed: \(hashedPassword)");
        }
        get {
            return "";
        }
    }

    var patientId: String = "";

    func makePostRequest<T: ApiRequest where T: Mappable>(requestObject: T) -> Promise<(T.ApiReturnType, Int)> {
        var parameters = requestObject.toJSON();
        parameters["password"] = hashedPassword;
        parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        parameters["patient_id"] = patientId;
        return Promise { resolve, reject in
            Alamofire.request(.POST, baseApiUrl + T.apiEndpoint, parameters: parameters)
                .responseString { response in
                    switch response.result {
                    case .Failure(let error):
                        reject(error);
                    case .Success:
                        let statusCode = response.response?.statusCode;
                        if let statusCode = statusCode where statusCode < 200 || statusCode >= 400 {
                            reject(ApiErrors.FailedStatus(code: statusCode));
                        } else {
                            var val = response.result.value;
                            if (T.apiEndpoint == "/upload") {
                                val = "{}";
                            }
                            let returnObject = Mapper<T.ApiReturnType>().map(val);
                            if let returnObject = returnObject {
                                resolve((returnObject, statusCode ?? 0));
                            } else {
                                reject(Error.errorWithCode(.DataSerializationFailed, failureReason: "Unable to decode response"));
                            }
                        }
                    }

            }
        }
    }



}