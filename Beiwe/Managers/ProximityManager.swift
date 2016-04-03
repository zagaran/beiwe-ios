//
//  ProximityManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/2/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation

class ProximityManager : DataServiceProtocol {

    let storeType = "proximity";
    let headers = ["timestamp", "event"]
    var store: DataStorage?;

    @objc func proximityStateDidChange(notification: NSNotification){
        // The stage did change: plugged, unplugged, full charge...
        var data: [String] = [ ];
        data.append(String(Int64(NSDate().timeIntervalSince1970 * 1000)));
        data.append(UIDevice.currentDevice().proximityState ? "NearUser" : "NotNearUser");

        dispatch_async(dispatch_get_main_queue()) {
            self.store?.store(data);
        }
    }

    func initCollecting() {
        store = DataStorageManager.sharedInstance.createStore(storeType, headers: headers);
    }

    func startCollecting() {
        print("Turning \(storeType) collection on");
        UIDevice.currentDevice().proximityMonitoringEnabled = true;
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.proximityStateDidChange), name: UIDeviceProximityStateDidChangeNotification, object: nil)

    }
    func pauseCollecting() {
        print("Pausing \(storeType) collection");
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceProximityStateDidChangeNotification, object:nil)
        store!.flush();
    }
    func finishCollecting() {
        print("Finish collecting \(storeType) collection");
        pauseCollecting();
        DataStorageManager.sharedInstance.closeStore(storeType);
        store = nil;
    }
}