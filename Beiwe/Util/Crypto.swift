//
//  Crypto.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/25/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import IDZSwiftCommonCrypto

class Crypto {
    static let sharedInstance = Crypto();

    func sha256Base64URL(str: String) -> String {
        let sha256: Digest = Digest(algorithm: .SHA256);
        sha256.update(str);
        let digest = sha256.final();
        let data = NSData(bytes: digest, length: digest.count);
        let base64Str = data.base64EncodedStringWithOptions([]);
        return base64ToBase64URL(base64Str);
    }

    func base64ToBase64URL(base64str: String) -> String {
        //        //replaceAll('/', '_').replaceAll('+', '-');
        return base64str.stringByReplacingOccurrencesOfString("/", withString: "_")
            .stringByReplacingOccurrencesOfString("+", withString: "-");
    }

}