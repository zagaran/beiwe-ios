//
//  GPSManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/29/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import CoreLocation
import Darwin


protocol DataServiceProtocol {
    func initCollecting();
    func startCollecting();
    func pauseCollecting();
    func finishCollecting();
}

class DataServiceStatus {
    let onDurationSeconds: Double;
    let offDurationSeconds: Double;
    var currentlyOn: Bool;
    var nextToggleTime: NSDate;
    let handler: DataServiceProtocol;

    init(onDurationSeconds: Int, offDurationSeconds: Int, handler: DataServiceProtocol) {
        self.onDurationSeconds = Double(onDurationSeconds);
        self.offDurationSeconds = Double(offDurationSeconds);
        self.handler = handler;
        currentlyOn = false;
        nextToggleTime = NSDate(); // NSDate().dateByAddingTimeInterval(self.offDurationSeconds);
    }
}

class GPSManager : NSObject, CLLocationManagerDelegate, DataServiceProtocol {
    let locationManager = CLLocationManager();
    var lastLocations: [CLLocation]?;
    var isCollectingGps: Bool = false;
    var dataCollectionServices: [DataServiceStatus] = [ ];
    static let headers = [ "timestamp", "latitude", "longitude", "altitude", "accuracy"];

    func startGpsAndTimer() {
        locationManager.delegate = self;
        locationManager.activityType = CLActivityType.Other;
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        } else {
            // Fallback on earlier versions
        };
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization();
        locationManager.startUpdatingLocation();

    }

    func dispatchToServices() -> NSDate {
        let currentDate = NSDate().timeIntervalSince1970;
        var nextServiceDate = currentDate + (15 * 60);

        for dataStatus in dataCollectionServices {
            var serviceDate = dataStatus.nextToggleTime.timeIntervalSince1970;
            if (serviceDate <= currentDate) {
                if (dataStatus.currentlyOn) {
                    dataStatus.handler.pauseCollecting();
                    dataStatus.currentlyOn = false;
                } else {
                    dataStatus.handler.startCollecting();
                    dataStatus.currentlyOn = true;
                }
                dataStatus.nextToggleTime = NSDate().dateByAddingTimeInterval(dataStatus.offDurationSeconds);
                serviceDate = dataStatus.nextToggleTime.timeIntervalSince1970;
            }
            nextServiceDate = min(nextServiceDate, serviceDate);
        }
        return NSDate(timeIntervalSince1970: nextServiceDate)
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        let nextServiceDate = dispatchToServices();

        if (isCollectingGps) {
            recordGpsData(manager, locations: locations);
        }

        let nextServiceSeconds = min(nextServiceDate.timeIntervalSince1970 - NSDate().timeIntervalSince1970, 1.0);

        locationManager.allowDeferredLocationUpdatesUntilTraveled(10000, timeout: nextServiceSeconds);

    }

    func recordGpsData(manager: CLLocationManager, locations: [CLLocation]) {
        //print("Record locations: \(locations)");
        for loc in locations {
            var data: [String] = [];

            //     static let headers = [ "timestamp", "latitude", "longitude", "altitude", "accuracy", "vert_accuracy"];

            data.append(String(Int(loc.timestamp.timeIntervalSince1970 * 1000)))
            data.append(String(loc.coordinate.latitude))
            data.append(String(loc.coordinate.longitude))
            data.append(String(loc.altitude))
            data.append(String(loc.horizontalAccuracy))
            DataStorageManager.sharedInstance.store("gps", headers: GPSManager.headers, data: data);
        }
    }

    func addDataService(on: Int, off: Int, handler: DataServiceProtocol) {
        let dataServiceStatus = DataServiceStatus(onDurationSeconds: on, offDurationSeconds: off, handler: handler);
        dataCollectionServices.append(dataServiceStatus);
    }


    /* Data service protocol */

    func initCollecting() {
        isCollectingGps = false;
    }
    func startCollecting() {
        print("Turning GPS collection on");
        isCollectingGps = true;
    }
    func pauseCollecting() {
        print("Pausing GPS collection");
        isCollectingGps = false;
        DataStorageManager.sharedInstance.flush("gps");
    }
    func finishCollecting() {
        isCollectingGps = false;
    }
}