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
    private let rsaKeyPrefix = "publicrsa:";


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

}