//
//  ReachabilityManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/3/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ReachabilitySwift
import PromiseKit

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

        self.store?.store(data);
        self.store?.flush();
    }

    func initCollecting() -> Bool {
        store = DataStorageManager.sharedInstance.createStore(storeType, headers: headers);
        return true;
    }

    func startCollecting() {
        log.info("Turning \(storeType) collection on");
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.reachabilityChanged), name: ReachabilityChangedNotification, object: nil)

    }
    func pauseCollecting() {
        log.info("Pausing \(storeType) collection");
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ReachabilityChangedNotification, object:nil)
        store!.flush();
    }
    func finishCollecting() -> Promise<Void> {
        log.info("Finish collecting \(storeType) collection");
        pauseCollecting();
        store = nil;
        return DataStorageManager.sharedInstance.closeStore(storeType);
    }
}