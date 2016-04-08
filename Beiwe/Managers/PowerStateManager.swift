//
//  PowerStateManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/1/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation

class PowerStateManager : DataServiceProtocol {

    let storeType = "powerState";
    let headers = ["timestamp", "event"]
    var store: DataStorage?;

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

        dispatch_async(dispatch_get_main_queue()) {
            self.store?.store(data);
            self.store?.flush();
        }
    }

    func initCollecting() -> Bool {
        store = DataStorageManager.sharedInstance.createStore(storeType, headers: headers);
        return true;
    }

    func startCollecting() {
        print("Turning \(storeType) collection on");
        UIDevice.currentDevice().batteryMonitoringEnabled = true;
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.batteryStateDidChange), name: UIDeviceBatteryStateDidChangeNotification, object: nil)

    }
    func pauseCollecting() {
        print("Pausing \(storeType) collection");
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceBatteryStateDidChangeNotification, object:nil)
        store!.flush();
    }
    func finishCollecting() {
        print("Finish collecting \(storeType) collection");
        pauseCollecting();
        DataStorageManager.sharedInstance.closeStore(storeType);
        store = nil;
    }
}