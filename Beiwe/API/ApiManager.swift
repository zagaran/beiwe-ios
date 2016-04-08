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

struct BodyResponse: Mappable {

    var body: String?;

    init(body: String?) {
        self.body = body;
    }
    init?(_ map: Map) {

    }

    mutating func mapping(map: Map) {
        body    <- map["body"];
    }
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
        //parameters["password"] = hashedPassword;
        //parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        //parameters["patient_id"] = patientId;
        parameters.removeValueForKey("password");
        parameters.removeValueForKey("device_id");
        parameters.removeValueForKey("patient_id");
        let credentialData = "\(patientId)@\(PersistentAppUUID.sharedInstance.uuid):\(hashedPassword)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])

        let headers = ["Authorization": "Basic \(base64Credentials)"]
        return Promise { resolve, reject in
            Alamofire.request(.POST, baseApiUrl + T.apiEndpoint, parameters: parameters, headers: headers)
                .responseString { response in
                    switch response.result {
                    case .Failure(let error):
                        reject(error);
                    case .Success:
                        let statusCode = response.response?.statusCode;
                        if let statusCode = statusCode where statusCode < 200 || statusCode >= 400 {
                            reject(ApiErrors.FailedStatus(code: statusCode));
                        } else {
                            var returnObject: T.ApiReturnType?;
                            if (T.ApiReturnType.self == BodyResponse.self) {
                                returnObject = BodyResponse(body: response.result.value) as? T.ApiReturnType;
                            } else {
                                returnObject = Mapper<T.ApiReturnType>().map(response.result.value);
                            }
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

    func arrayPostRequest<T: ApiRequest where T: Mappable>(requestObject: T) -> Promise<([T.ApiReturnType], Int)> {
        var parameters = requestObject.toJSON();
        //parameters["password"] = hashedPassword;
        //parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        //parameters["patient_id"] = patientId;
        parameters.removeValueForKey("password");
        parameters.removeValueForKey("device_id");
        parameters.removeValueForKey("patient_id");
        let credentialData = "\(patientId)@\(PersistentAppUUID.sharedInstance.uuid):\(hashedPassword)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])

        let headers = ["Authorization": "Basic \(base64Credentials)"]
        return Promise { resolve, reject in
            Alamofire.request(.POST, baseApiUrl + T.apiEndpoint, parameters: parameters, headers: headers)
                .responseString { response in
                    switch response.result {
                    case .Failure(let error):
                        reject(error);
                    case .Success:
                        let statusCode = response.response?.statusCode;
                        if let statusCode = statusCode where statusCode < 200 || statusCode >= 400 {
                            reject(ApiErrors.FailedStatus(code: statusCode));
                        } else {
                            var returnObject: [T.ApiReturnType]?;
                            print("Value: \(response.result.value)");
                            returnObject = Mapper<T.ApiReturnType>().mapArray(response.result.value);
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


    func makeUploadRequest<T: ApiRequest where T: Mappable>(requestObject: T, file: NSURL) -> Promise<(T.ApiReturnType, Int)> {
        var parameters = requestObject.toJSON();
        //parameters["password"] = hashedPassword;
        //parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        //parameters["patient_id"] = patientId;
        parameters.removeValueForKey("password");
        parameters.removeValueForKey("device_id");
        parameters.removeValueForKey("patient_id");
        let credentialData = "\(patientId)@\(PersistentAppUUID.sharedInstance.uuid):\(hashedPassword)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])

        let headers = ["Authorization": "Basic \(base64Credentials)"]
        var request = NSMutableURLRequest(URL: NSURL(string: baseApiUrl + T.apiEndpoint)!);
        request.HTTPMethod = "POST";
        for (k,v) in headers {
            request.addValue(v, forHTTPHeaderField: k);
        }
        let encoding = Alamofire.ParameterEncoding.URLEncodedInURL;
        (request, _) = encoding.encode(request, parameters: parameters)
        return Promise { resolve, reject in
            Alamofire.upload(request, file: file)
                .responseString { response in
                    switch response.result {
                    case .Failure(let error):
                        reject(error);
                    case .Success:
                        let statusCode = response.response?.statusCode;
                        if let statusCode = statusCode where statusCode < 200 || statusCode >= 400 {
                            reject(ApiErrors.FailedStatus(code: statusCode));
                        } else {
                            var returnObject: T.ApiReturnType?;
                            if (T.ApiReturnType.self == BodyResponse.self) {
                                returnObject = BodyResponse(body: response.result.value) as? T.ApiReturnType;
                            } else {
                                returnObject = Mapper<T.ApiReturnType>().map(response.result.value);
                            }
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

    func makeMultipartUploadRequest<T: ApiRequest where T: Mappable>(requestObject: T, file: NSURL) -> Promise<(T.ApiReturnType, Int)> {
        var parameters = requestObject.toJSON();
        //parameters["password"] = hashedPassword;
        //parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        //parameters["patient_id"] = patientId;
        parameters.removeValueForKey("password");
        parameters.removeValueForKey("device_id");
        parameters.removeValueForKey("patient_id");
        let credentialData = "\(patientId)@\(PersistentAppUUID.sharedInstance.uuid):\(hashedPassword)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])

        let headers = ["Authorization": "Basic \(base64Credentials)"]
        /*
        var request = NSMutableURLRequest(URL: NSURL(string: baseApiUrl + T.apiEndpoint)!);
        request.HTTPMethod = "POST";
        for (k,v) in headers {
            request.addValue(v, forHTTPHeaderField: k);
        }
        let encoding = Alamofire.ParameterEncoding.URLEncodedInURL;
        (request, _) = encoding.encode(request, parameters: parameters)
        */
        return Promise { resolve, reject in
            Alamofire.upload(.POST, baseApiUrl + T.apiEndpoint, headers: headers, multipartFormData: { multipartFormData in
                for (k, v) in parameters {
                    multipartFormData.appendBodyPart(data: v.dataUsingEncoding(NSUTF8StringEncoding)!, name: k)
                }
                multipartFormData.appendBodyPart(fileURL: file, name: "file")

                },
                encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .Success(let upload, _, _):
                        upload.responseString { response in
                            switch response.result {
                            case .Failure(let error):
                                reject(error);
                            case .Success:
                                let statusCode = response.response?.statusCode;
                                if let statusCode = statusCode where statusCode < 200 || statusCode >= 400 {
                                    reject(ApiErrors.FailedStatus(code: statusCode));
                                } else {
                                    var returnObject: T.ApiReturnType?;
                                    if (T.ApiReturnType.self == BodyResponse.self) {
                                        returnObject = BodyResponse(body: response.result.value) as? T.ApiReturnType;
                                    } else {
                                        returnObject = Mapper<T.ApiReturnType>().map(response.result.value);
                                    }
                                    if let returnObject = returnObject {
                                        resolve((returnObject, statusCode ?? 0));
                                    } else {
                                        reject(Error.errorWithCode(.DataSerializationFailed, failureReason: "Unable to decode response"));
                                    }
                                }
                            }
                            
                        }

                    case .Failure(let encodingError):
                        reject(encodingError);
                    }
            });
        }
    }

}