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
    static let bundlePrefix = (NSBundle.mainBundle().bundleIdentifier ?? "com.rocketarmstudios.beiwe")
    private let keychain: KeychainSwift
    private let passwordKeyPrefix = "password:";
    private let rsaKeyPrefix = PersistentPasswordManager.bundlePrefix + ".rsapk.";

    init() {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
             keychain = KeychainSwift(keyPrefix: PersistentPasswordManager.bundlePrefix + ".")
        #else
            keychain = KeychainSwift()
        #endif
    }

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

    func storePublicKeyForStudy(publicKey: String, patientId: String, study: String = Constants.defaultStudyId) throws {
        try SwiftyRSA.storePublicKey(publicKey, keyId: publicKeyName(patientId, study: study))
    }

    func publicKeyName(patientId: String, study: String = Constants.defaultStudyId) -> String {
        return keyForStudy(study, prefix: rsaKeyPrefix) + "." + patientId;
    }


}