//
//  GyroManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 4/3/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import CoreMotion

class GyroManager : DataServiceProtocol {
    let motionManager = AppDelegate.sharedInstance().motionManager;

    let headers = ["timestamp", "accuracy", "x", "y", "z"]
    let storeType = "gyro";
    var store: DataStorage?;
    var offset: Double = 0;

    func initCollecting() {
        store = DataStorageManager.sharedInstance.createStore(storeType, headers: headers);
        // Get NSTimeInterval of uptime i.e. the delta: now - bootTime
        let uptime: NSTimeInterval = NSProcessInfo.processInfo().systemUptime;
        // Now since 1970
        let nowTimeIntervalSince1970: NSTimeInterval  = NSDate().timeIntervalSince1970;
        // Voila our offset
        self.offset = nowTimeIntervalSince1970 - uptime;
        motionManager.gyroUpdateInterval = 0.1;
    }

    func startCollecting() {
        print("Turning \(storeType) collection on");
        let queue = NSOperationQueue.mainQueue();


        motionManager.startGyroUpdatesToQueue(queue) {
            (gyroData, error) in

            if let gyroData = gyroData {
                var data: [String] = [ ];
                let timestamp: Double = gyroData.timestamp + self.offset;
                data.append(String(Int64(timestamp * 1000)));
                data.append(AppDelegate.sharedInstance().modelVersionId);
                data.append(String(gyroData.rotationRate.x))
                data.append(String(gyroData.rotationRate.y))
                data.append(String(gyroData.rotationRate.z))

                self.store?.store(data);
            }
        }
    }
    func pauseCollecting() {
        print("Pausing \(storeType) collection");
        motionManager.stopGyroUpdates();
        store?.flush();
    }
    func finishCollecting() {
        print ("Finishing \(storeType) collecting");
        pauseCollecting();
        DataStorageManager.sharedInstance.closeStore(storeType);
        store = nil;
    }
}