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
    var isHandlingPeriodic = false;

    var isStudyLoaded: Bool {
        return currentStudy != nil;
    }

    func loadDefaultStudy() -> Promise<Bool> {
        currentStudy = nil;
        gpsManager = nil;
        return firstly { _ -> Promise<[Study]> in
            return Recline.shared.queryAll()
        }.then { studies -> Promise<Bool> in
            print("All Studies: \(studies)")
            if (studies.count > 0) {
                self.currentStudy = studies[0];
            }
            return Promise(true);
        }

    }

    func startStudyDataServices() {
        guard let currentStudy = currentStudy where gpsManager == nil else {
            return;
        }
        /* Setup APIManager's security */
        ApiManager.sharedInstance.password = PersistentPasswordManager.sharedInstance.passwordForStudy() ?? "";
        if let patientId = currentStudy.patientId {
            ApiManager.sharedInstance.patientId = patientId;
        }
        DataStorageManager.sharedInstance.setCurrentStudy(self.currentStudy!);
        self.prepareDataServices();
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

    func setConsented() -> Promise<Bool> {
        guard let study = currentStudy, studySettings = study.studySettings else {
            return Promise(false);
        }
        let currentTime: Int64 = Int64(NSDate().timeIntervalSince1970);
        study.nextUploadCheck = currentTime + studySettings.uploadDataFileFrequencySeconds;
        study.nextSurveyCheck = currentTime + studySettings.checkForNewSurveysFreqSeconds;

        study.participantConsented = true;
        return Recline.shared.save(study).then { _ -> Promise<Bool> in
            return self.checkSurveys();
        }
    }

    func leaveStudy() -> Promise<Bool> {
        guard let study = currentStudy else {
            return Promise(true);
        }

        gpsManager?.stopAndClear();
        gpsManager = nil;
        return Recline.shared.purge(study).then { _ -> Promise<Bool> in
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

            self.currentStudy = nil;

            return Promise(true);

       }

    }

    func periodicEvents() {
        guard let currentStudy = currentStudy where isHandlingPeriodic == false else {
            return;
        }
        let currentTime: Int64 = Int64(NSDate().timeIntervalSince1970);
        let nextSurvey = currentStudy.nextSurveyCheck ?? 0;
        let nextUpload = currentStudy.nextUploadCheck ?? 0;
        if (currentTime > nextSurvey) {
            setNextSurveyTime().then { _ -> Void in
                self.isHandlingPeriodic = false;
                self.checkSurveys();
                }.error { _ -> Void in
                    print("Error checking for surveys");
            }
        }
        else if (currentTime > nextUpload) {
            setNextUploadTime().then { _ -> Void in
                self.upload();
                }.error { _ -> Void in
                    print("Error checking for uploades")
            }
        }

    }

    func checkSurveys() -> Promise<Bool> {
        guard let study = currentStudy, studySettings = study.studySettings else {
            return Promise(false);
        }
        print("Checking for surveys...");
        study.nextSurveyCheck = Int64(NSDate().timeIntervalSince1970) + studySettings.checkForNewSurveysFreqSeconds;
        return Recline.shared.save(study).then { _ -> Promise<([Survey], Int)> in
                let surveyRequest = GetSurveysRequest();
                return ApiManager.sharedInstance.arrayPostRequest(surveyRequest);
            }.then { (surveys, _)  -> Promise<Bool> in
                print("Surveys: \(surveys)");
                return Promise(true);
            }

    }

    func setNextUploadTime() -> Promise<Bool> {
        guard let study = currentStudy, studySettings = study.studySettings else {
            return Promise(true);
        }

        study.nextUploadCheck = Int64(NSDate().timeIntervalSince1970) + studySettings.uploadDataFileFrequencySeconds;
        return Recline.shared.save(study).then { _ -> Promise<Bool> in
            return Promise(true);
        }
    }

    func setNextSurveyTime() -> Promise<Bool> {
        guard let study = currentStudy, studySettings = study.studySettings else {
            return Promise(true);
        }

        study.nextSurveyCheck = Int64(NSDate().timeIntervalSince1970) + studySettings.checkForNewSurveysFreqSeconds
        return Recline.shared.save(study).then { _ -> Promise<Bool> in
            return Promise(true);
        }

    }

    func upload() {
        if (isUploading) {
            return;
        }

        print("Checking for uploads...");
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

        var promiseChain = setNextUploadTime();
        var numFiles = 0;

        if let enumerator = enumerator {
            while let filename = enumerator.nextObject() as? String {
                if (filename.hasSuffix(DataStorageManager.dataFileSuffix)) {
                    let filePath = DataStorageManager.uploadDataDirectory().URLByAppendingPathComponent(filename);
                    let uploadRequest = UploadRequest(fileName: filename, filePath: filePath.path!);
                    let promise: Promise<Bool> =
                        //ApiManager.sharedInstance.makePostRequest(uploadRequest).then { _ -> Promise<Bool> in
                        //ApiManager.sharedInstance.makeUploadRequest(uploadRequest, file: filePath).then { _ -> Promise<Bool> in

                        ApiManager.sharedInstance.makeMultipartUploadRequest(uploadRequest, file: filePath).then { _ -> Promise<Bool> in
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

        isUploading = true;

        promiseChain.then { results -> Void in
            print("OK uploading \(numFiles). \(results)");
            self.isUploading = false;
            }.error { error in
                print("Error uploading: \(error)");
                self.setNextUploadTime();
                self.isUploading = false;
        }
    }
}