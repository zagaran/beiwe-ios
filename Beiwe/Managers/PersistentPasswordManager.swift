//
//  PersistentPasswordManager
//  Beiwe
//
//  Created by Keary Griffin on 3/21/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import KeychainSwift;

struct PersistentPasswordManager {
    static let sharedInstance = PersistentPasswordManager();

    private let keychain = KeychainSwift()
    private let passwordKeyPrefix = "password:";
    private let rsaKeyPrefix = "com.rocketarmstudios.beiwe.rsapk.";


    private func keyForStudy(study: String, prefix: String) -> String {
        let key = prefix + study;
        return key;
    }

    func passwordForStudy(study: String = Constants.defaultStudyId) -> String? {
        return keychain.get(keyForStudy(study, prefix: passwordKeyPrefix));
    }

    func storePassword(password: String, study: String = Constants.defaultStudyId) {
        keychain.set(password, forKey: keyForStudy(study, prefix: passwordKeyPrefix), withAccess: .AccessibleAlwaysThisDeviceOnly);
    }

    func storePublicKeyForStudy(publicKey: String, study: String = Constants.defaultStudyId) throws {
        try SwiftyRSA.storePublicKey(publicKey, keyId: keyForStudy(study, prefix: rsaKeyPrefix))
    }

    func publicKeyName(study: String = Constants.defaultStudyId) -> String {
        return keyForStudy(study, prefix: rsaKeyPrefix);
    }


}