//
//  PersistentAppUUID.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/21/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import KeychainSwift;

struct PersistentAppUUID {
    static let sharedInstance = PersistentAppUUID();

    private let keychain = KeychainSwift()
    private let uuidKey = "privateAppUuid";

    let uuid: String;

    private init() {
        if let u = keychain.get(uuidKey) {
            uuid = u;
        } else {
            uuid = NSUUID().UUIDString;
            keychain.set(uuid, forKey: uuidKey, withAccess: .AccessibleAlwaysThisDeviceOnly);
        }
    }
}