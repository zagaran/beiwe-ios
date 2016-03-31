//
//  AccelerometerManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/31/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import CoreMotion

class AccelerometerManager : DataServiceProtocol {

    static let headers = ["timestamp", "accuracy", "x", "y", "z"]
    let motionManager = CMMotionManager();
    var accelStore: DataStorage?;
    var offset: Double = 0;

    func initCollecting() {
        accelStore = DataStorageManager.sharedInstance.createStore("accel", headers: AccelerometerManager.headers);
        motionManager.accelerometerUpdateInterval = 1;
        // Get NSTimeInterval of uptime i.e. the delta: now - bootTime
        let uptime: NSTimeInterval = NSProcessInfo.processInfo().systemUptime;

        // Now since 1970
        let nowTimeIntervalSince1970: NSTimeInterval  = NSDate().timeIntervalSince1970;

        // Voila our offset
        self.offset = nowTimeIntervalSince1970 - uptime;

        motionManager.accelerometerUpdateInterval = 0.1;

    }

    func startCollecting() {
        print("Turning Accel collection on");
        let queue = NSOperationQueue.mainQueue();


        motionManager.startAccelerometerUpdatesToQueue(queue) {
            (accelData, error) in

            if let accelData = accelData {
                var data: [String] = [ ];
                let timestamp: Double = accelData.timestamp + self.offset;
                data.append(String(Int64(timestamp * 1000)));
                data.append("unknown");
                data.append(String(accelData.acceleration.x))
                data.append(String(accelData.acceleration.y))
                data.append(String(accelData.acceleration.z))

                self.accelStore?.store(data);
            }
        }
    }
    func pauseCollecting() {
        print("Pausing Accel collection");
        motionManager.stopAccelerometerUpdates();
        accelStore?.flush();
    }
    func finishCollecting() {
        DataStorageManager.sharedInstance.closeStore("accel");
        accelStore = nil;
    }
}