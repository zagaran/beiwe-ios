//
//  PowerStateManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/1/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import PromiseKit
import EmitterKit

class PowerStateManager : DataServiceProtocol {

    let storeType = "powerState";
    let headers = ["timestamp", "event", "level"]
    var store: DataStorage?;
    var listeners: [Listener] = [];

    @objc func batteryStateDidChange(notification: NSNotification){
        // The stage did change: plugged, unplugged, full charge...
        var data: [String] = [ ];
        data.append(String(Int64(NSDate().timeIntervalSince1970 * 1000)));
        var state: String;
        switch(UIDevice.currentDevice().batteryState) {
        case .Charging:
            state = "Charging";
        case .Full:
            state = "Full";
        case .Unplugged:
            state = "Unplugged";
        case .Unknown:
            state = "PowerUnknown";
        }
        data.append(state);
        data.append(String(UIDevice.currentDevice().batteryLevel));

        self.store?.store(data);
        self.store?.flush();
    }

    func didLockUnlock(isLocked: Bool) {
        log.info("Lock state data changed: \(isLocked)");
        var data: [String] = [ ];
        data.append(String(Int64(NSDate().timeIntervalSince1970 * 1000)));
        let state: String = isLocked ? "Locked" : "Unlocked";
        data.append(state);
        data.append(String(UIDevice.currentDevice().batteryLevel));

        self.store?.store(data);
        self.store?.flush();

    }

    func initCollecting() -> Bool {
        store = DataStorageManager.sharedInstance.createStore(storeType, headers: headers);
        return true;
    }

    func startCollecting() {
        log.info("Turning \(storeType) collection on");
        UIDevice.currentDevice().batteryMonitoringEnabled = true;
        listeners += AppDelegate.sharedInstance().lockEvent.on { [weak self] locked in
            self?.didLockUnlock(locked);
        }
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.batteryStateDidChange), name: UIDeviceBatteryStateDidChangeNotification, object: nil)

    }
    func pauseCollecting() {
        log.info("Pausing \(storeType) collection");
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceBatteryStateDidChangeNotification, object:nil)
        listeners = [ ];
        store!.flush();
    }
    func finishCollecting() -> Promise<Void> {
        log.info("Finish collecting \(storeType) collection");
        pauseCollecting();
        store = nil;
        return DataStorageManager.sharedInstance.closeStore(storeType);
    }
}