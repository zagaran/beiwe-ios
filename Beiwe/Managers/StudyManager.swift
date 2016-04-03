//
//  StudyManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/29/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import PromiseKit

class StudyManager {
    static let sharedInstance = StudyManager();
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate

    var currentStudy: Study?;
    var gpsManager: GPSManager?;
    var isUploading = false;

    func loadDefaultStudy()  {
        currentStudy = nil;
        gpsManager = nil;
        firstly { _ -> Promise<[Study]> in
            return Recline.shared.queryAll()
        }.then { studies -> Void in
            print("All Studies: \(studies)")
            if (studies.count > 0) {
                self.currentStudy = studies[0];
                /* Setup APIManager's security */
                ApiManager.sharedInstance.password = PersistentPasswordManager.sharedInstance.passwordForStudy() ?? "";
                if let patientId = self.currentStudy?.patientId {
                    ApiManager.sharedInstance.patientId = patientId;
                }
                DataStorageManager.sharedInstance.setCurrentStudy(self.currentStudy!);
                self.prepareDataServices();
            }
            self.appDelegate.displayCurrentMainView();
        }.error { err -> Void in
            print("Error reading studies from database");
        }

    }

    func prepareDataServices() {
        guard let studySettings = currentStudy?.studySettings else {
            return;
        }

        DataStorageManager.sharedInstance.createDirectories();
        /* Move non current files out.  Probably not necessary, would happen later anyway */
        DataStorageManager.sharedInstance.prepareForUpload();
        gpsManager = GPSManager();
        if (studySettings.gps && studySettings.gpsOnDurationSeconds > 0) {
            gpsManager!.addDataService(studySettings.gpsOnDurationSeconds, off: studySettings.gpsOffDurationSeconds, handler: gpsManager!)
        }
        if (studySettings.accelerometer && studySettings.gpsOnDurationSeconds > 0) {
            gpsManager!.addDataService(studySettings.accelerometerOnDurationSeconds, off: studySettings.accelerometerOffDurationSeconds, handler: AccelerometerManager());
        }
        if (studySettings.powerState) {
            gpsManager!.addDataService(PowerStateManager());
        }

        if (studySettings.proximity) {
            gpsManager!.addDataService(ProximityManager());
        }

        if (studySettings.reachability) {
            gpsManager!.addDataService(ReachabilityManager());
        }

        if (studySettings.gyro) {
            gpsManager!.addDataService(studySettings.gyroOnDurationSeconds, off: studySettings.gyroOffDurationSeconds, handler: GyroManager());
        }

        if (studySettings.magnetometer && studySettings.magnetometerOnDurationSeconds > 0) {
            gpsManager!.addDataService(studySettings.magnetometerOnDurationSeconds, off: studySettings.magnetometerOffDurationSeconds, handler: MagnetometerManager());
        }

        if (studySettings.motion && studySettings.motionOnDurationSeconds > 0) {
            gpsManager!.addDataService(studySettings.motionOnDurationSeconds, off: studySettings.motionOffDurationSeconds, handler: DeviceMotionManager());
        }



        gpsManager!.startGpsAndTimer();
    }

    func leaveStudy() {
        guard let study = currentStudy else {
            return;
        }

        gpsManager?.stopAndClear();
        gpsManager = nil;
        Recline.shared.purge(study).then { _ -> Void in
            let fileManager = NSFileManager.defaultManager()
            var enumerator = fileManager.enumeratorAtPath(DataStorageManager.uploadDataDirectory().path!);

            if let enumerator = enumerator {
                while let filename = enumerator.nextObject() as? String {
                    if (filename.hasSuffix(DataStorageManager.dataFileSuffix)) {
                        let filePath = DataStorageManager.uploadDataDirectory().URLByAppendingPathComponent(filename);
                        try fileManager.removeItemAtURL(filePath);
                    }
                }
            }

            enumerator = fileManager.enumeratorAtPath(DataStorageManager.currentDataDirectory().path!);

            if let enumerator = enumerator {
                while let filename = enumerator.nextObject() as? String {
                    if (filename.hasSuffix(DataStorageManager.dataFileSuffix)) {
                        let filePath = DataStorageManager.currentDataDirectory().URLByAppendingPathComponent(filename);
                        try fileManager.removeItemAtURL(filePath);
                    }
                }
            }

            self.loadDefaultStudy();

            }.error { err -> Void in
                print("Error leaving study!");
        };

    }

    func upload() {
        if (isUploading) {
            return;
        }

        DataStorageManager.sharedInstance.prepareForUpload();

        let fileManager = NSFileManager.defaultManager()
        let enumerator = fileManager.enumeratorAtPath(DataStorageManager.uploadDataDirectory().path!);

        /*
        var promises: [Promise<Bool>] = [ ];

        if let enumerator = enumerator {
            while let filename = enumerator.nextObject() as? String {
                if (filename.hasSuffix(DataStorageManager.dataFileSuffix)) {
                    let filePath = DataStorageManager.uploadDataDirectory().URLByAppendingPathComponent(filename);
                    let uploadRequest = UploadRequest(fileName: filename, filePath: filePath.path!);
                    let promise: Promise<Bool> = ApiManager.sharedInstance.makePostRequest(uploadRequest).then { _ -> Promise<Bool> in
                        print("Finished uploading: \(filename), removing.");
                        try fileManager.removeItemAtURL(filePath);
                        return Promise(true);
                        }
                    promises.append(promise);
                }
            }
        }

        if (promises.count > 0) {
            isUploading = true;
            when(promises).then { results -> Void in
                print("OK uploading. \(results)");
                self.isUploading = false;
            }.error { error in
                print("Error uploading: \(error)");
                self.isUploading = false;
            }
        }
        */

        var promiseChain = Promise(true);
        var numFiles = 0;

        if let enumerator = enumerator {
            while let filename = enumerator.nextObject() as? String {
                if (filename.hasSuffix(DataStorageManager.dataFileSuffix)) {
                    let filePath = DataStorageManager.uploadDataDirectory().URLByAppendingPathComponent(filename);
                    let uploadRequest = UploadRequest(fileName: filename, filePath: filePath.path!);
                    let promise: Promise<Bool> = ApiManager.sharedInstance.makePostRequest(uploadRequest).then { _ -> Promise<Bool> in
                        print("Finished uploading: \(filename), removing.");
                        try fileManager.removeItemAtURL(filePath);
                        return Promise(true);
                    }
                    promiseChain = promiseChain.then {_ in 
                        return promise;
                    }
                    numFiles = numFiles + 1;
                    //promises.append(promise);
                }
            }
        }

        if (numFiles > 0) {
            isUploading = true;
            promiseChain.then { results -> Void in
                print("OK uploading. \(results)");
                self.isUploading = false;
                }.error { error in
                    print("Error uploading: \(error)");
                    self.isUploading = false;
            }
        }

    }
}