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


    private func keyForStudy(study: String) -> String {
        let key = passwordKeyPrefix + study;
        return key;
    }
    func passwordForStudy(study: String = "default") -> String? {
        return keychain.get(keyForStudy(study));
    }

    func storePassword(password: String, study: String = "default") {
        keychain.set(password, forKey: keyForStudy(study), withAccess: .AccessibleAlwaysThisDeviceOnly);
    }
}