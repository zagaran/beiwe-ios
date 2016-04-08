//
//  ReachabilityManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/3/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ReachabilitySwift

class ReachabilityManager : DataServiceProtocol {

    let storeType = "reachability";
    let headers = ["timestamp", "event"]
    var store: DataStorage?;

    @objc func reachabilityChanged(notification: NSNotification){
        guard let reachability = AppDelegate.sharedInstance().reachability else {
            return;
        }
        var reachState: String;
        if reachability.isReachable() {
            if reachability.isReachableViaWiFi() {
                reachState = "wifi";
            } else {
                reachState = "cellular";
            }
        } else {
            reachState = "unreachable";
        }

        var data: [String] = [ ];
        data.append(String(Int64(NSDate().timeIntervalSince1970 * 1000)));
        data.append(reachState);

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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.reachabilityChanged), name: ReachabilityChangedNotification, object: nil)

    }
    func pauseCollecting() {
        print("Pausing \(storeType) collection");
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ReachabilityChangedNotification, object:nil)
        store!.flush();
    }
    func finishCollecting() {
        print("Finish collecting \(storeType) collection");
        pauseCollecting();
        DataStorageManager.sharedInstance.closeStore(storeType);
        store = nil;
    }
}