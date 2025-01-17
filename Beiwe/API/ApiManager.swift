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

enum ApiErrors: Error {
    case failedStatus(code: Int)
    case fileNotFound
}

struct BodyResponse: Mappable {

    var body: String?;

    init(body: String?) {
        self.body = body;
    }
    init?(map: Map) {

    }

    mutating func mapping(map: Map) {
        body    <- map["body"];
    }
}


class ApiManager {
    static let sharedInstance = ApiManager();
    fileprivate let defaultBaseApiUrl = Configuration.sharedInstance.settings["server-url"] as! String;
    fileprivate var deviceId = PersistentAppUUID.sharedInstance.uuid;

    fileprivate var hashedPassword = "";

    var password: String {
        set {
            hashedPassword = Crypto.sharedInstance.sha256Base64URL(newValue);
        }
        get {
            return "";
        }
    }

    var fcmToken: String?;
    var patientId: String = "";
    var customApiUrl: String?;
    var baseApiUrl: String {
        get {
            return customApiUrl ?? defaultBaseApiUrl;
        }
    }

    func generateHeaders(_ password: String? = nil) -> [String:String] {

        /*
        var hash = hashedPassword;
        if let password = password {
            hash = Crypto.sharedInstance.sha256Base64URL(password);
        }
        let credentialData = "\(patientId)@\(PersistentAppUUID.sharedInstance.uuid):\(hash)".dataUsingEncoding(NSUTF8StringEncoding)!
        let base64Credentials = credentialData.base64EncodedStringWithOptions([])
        */
        let headers = [
            //"Authorization": "Basic \(base64Credentials)",
            "Beiwe-Api-Version": "2",
            "Accept": "application/vnd.beiwe.api.v2, application/json"
        ]
        return headers;
    }

    static func serialErr() -> NSError {
        return NSError(domain: "com.rf.beiwe.studies", code: 2, userInfo: nil);
    }

    func makePostRequest<T: ApiRequest>(_ requestObject: T, password: String? = nil) -> Promise<(T.ApiReturnType, Int)> where T: Mappable {
        var parameters = requestObject.toJSON();
        parameters["password"] = (password == nil) ? hashedPassword : Crypto.sharedInstance.sha256Base64URL(password!);
        parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        parameters["patient_id"] = patientId;
        //parameters.removeValueForKey("password");
        //parameters.removeValueForKey("device_id");
        //parameters.removeValueForKey("patient_id");
        let headers = generateHeaders(password);
        return Promise { seal in
            Alamofire.request(baseApiUrl + T.apiEndpoint, method: .post, parameters: parameters, headers: headers)
                .responseString { response in
                    switch response.result {
                    case .failure(let error):
                        return seal.reject(error);
                    case .success:
                        let statusCode = response.response?.statusCode;
                        if let statusCode = statusCode, (statusCode < 200 || statusCode >= 400) {
                            return seal.reject(ApiErrors.failedStatus(code: statusCode));
                        } else {
                            var returnObject: T.ApiReturnType?;
                            if (T.ApiReturnType.self == BodyResponse.self) {
                                returnObject = BodyResponse(body: response.result.value) as? T.ApiReturnType;
                            } else if (T.ApiReturnType.self == StudySettings.self) {
                                do {
                                    var json = try JSONSerialization.jsonObject(with: Data(response.result.value?.utf8 ?? "".utf8)) as? [String:Any]
                                    if (json?["ios_plist"] is NSNull || json?["ios_plist"] == nil) {
                                        json?["ios_plist"] = [
                                            "CLIENT_ID": "",
                                            "REVERSED_CLIENT_ID": "",
                                            "API_KEY": "",
                                            "GCM_SENDER_ID": "",
                                            "PLIST_VERSION": "1",
                                            "BUNDLE_ID": "",
                                            "PROJECT_ID": "",
                                            "STORAGE_BUCKET": "",
                                            "IS_ADS_ENABLED": false,
                                            "IS_ANALYTICS_ENABLED": false,
                                            "IS_APPINVITE_ENABLED": true,
                                            "IS_GCM_ENABLED": true,
                                            "IS_SIGNIN_ENABLED": true,
                                            "GOOGLE_APP_ID": "",
                                            "DATABASE_URL": "",
                                        ]
                                    }
                                    let jsonObject = try? JSONSerialization.data(withJSONObject: json, options: [])
                                    if let jsonString = String(data: jsonObject!, encoding: .utf8) {
                                        returnObject = Mapper<T.ApiReturnType>().map(JSONString: jsonString);
                                    }
                                } catch {
                                    log.error("Unable to create default firebase credentials plist")
                                    AppEventManager.sharedInstance.logAppEvent(event: "push_notification", msg: "Unable to create default firebase credentials plist")
                                }
                            } else {
                                returnObject = Mapper<T.ApiReturnType>().map(JSONString: response.result.value ?? "");
                            }
                            if let returnObject = returnObject {
                                return seal.fulfill((returnObject, statusCode ?? 0));
                            } else {
                                return seal.reject(ApiManager.serialErr());
                            }
                        }
                    }

            }
        }
    }


    func arrayPostRequest<T: ApiRequest>(_ requestObject: T) -> Promise<([T.ApiReturnType], Int)> where T: Mappable {
        var parameters = requestObject.toJSON();
        parameters["password"] = hashedPassword;
        parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        parameters["patient_id"] = patientId;
        //parameters.removeValueForKey("password");
        //parameters.removeValueForKey("device_id");
        //parameters.removeValueForKey("patient_id");
        let headers = generateHeaders();
        return Promise { seal in
            Alamofire.request(baseApiUrl + T.apiEndpoint, method: .post,parameters: parameters, headers: headers)
                .responseString { response in
                    switch response.result {
                    case .failure(let error):
                        seal.reject(error);
                    case .success:
                        let statusCode = response.response?.statusCode;
                        if let statusCode = statusCode, statusCode < 200 || statusCode >= 400 {
                            seal.reject(ApiErrors.failedStatus(code: statusCode));
                        } else {
                            var returnObject: [T.ApiReturnType]?;
                            returnObject = Mapper<T.ApiReturnType>().mapArray(JSONString: response.result.value ?? "");
                            if let returnObject = returnObject {
                                seal.fulfill((returnObject, statusCode ?? 0));
                            } else {
                                seal.reject(ApiManager.serialErr());
                            }
                        }
                    }

            }
        }
    }

    func makeMultipartUploadRequest<T: ApiRequest>(_ requestObject: T, file: URL) -> Promise<(T.ApiReturnType, Int)> where T: Mappable {
        var parameters = requestObject.toJSON();
        parameters["password"] = hashedPassword;
        parameters["device_id"] = PersistentAppUUID.sharedInstance.uuid;
        parameters["patient_id"] = patientId;
        //parameters.removeValueForKey("password");
        //parameters.removeValueForKey("device_id");
        //parameters.removeValueForKey("patient_id");

        let headers = generateHeaders();
        let url = baseApiUrl + T.apiEndpoint;
        return Promise { seal in
            Alamofire.upload(multipartFormData: { multipartFormData in
                for (k, v) in parameters {
                    multipartFormData.append (String(describing: v).data(using: .utf8)!, withName: k)
                }
                multipartFormData.append(file, withName: "file")

                },
                to: url,
                method: .post,
                headers: headers,
                encodingCompletion: { encodingResult in
                    switch encodingResult {
                    case .success(let upload, _, _):
                        upload.responseString { response in
                            switch response.result {
                            case .failure(let error):
                                seal.reject(error);
                            case .success:
                                let statusCode = response.response?.statusCode;
                                if let statusCode = statusCode, statusCode < 200 || statusCode >= 400 {
                                    seal.reject(ApiErrors.failedStatus(code: statusCode));
                                } else {
                                    var returnObject: T.ApiReturnType?;
                                    if (T.ApiReturnType.self == BodyResponse.self) {
                                        returnObject = BodyResponse(body: response.result.value) as? T.ApiReturnType;
                                    } else {
                                        returnObject = Mapper<T.ApiReturnType>().map(JSONString: response.result.value ?? "");
                                    }
                                    if let returnObject = returnObject {
                                        seal.fulfill((returnObject, statusCode ?? 0));
                                    } else {
                                        seal.reject(ApiManager.serialErr());
                                    }
                                }
                            }
                            
                        }

                    case .failure(let encodingError):
                        seal.reject(encodingError);
                    }
            });
        }
    }

}
