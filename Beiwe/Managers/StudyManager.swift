//
//  StudyManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/29/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import PromiseKit
import ReachabilitySwift
import EmitterKit
import Crashlytics

class StudyManager {
    static let sharedInstance = StudyManager();
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let calendar = NSCalendar.currentCalendar();

    var currentStudy: Study?;
    var gpsManager: GPSManager?;
    var isUploading = false;
    var isHandlingPeriodic = false;
    let surveysUpdatedEvent: Signal = Signal();

    var isStudyLoaded: Bool {
        return currentStudy != nil;
    }

    func loadDefaultStudy() -> Promise<Bool> {
        currentStudy = nil;
        gpsManager = nil;
        return firstly { _ -> Promise<[Study]> in
            return Recline.shared.queryAll()
        }.then { studies -> Promise<Bool> in
            if (studies.count > 1) {
                log.error("Multiple Studies: \(studies)")
                Crashlytics.sharedInstance().recordError(NSError(domain: "com.rf.beiwe.studies", code: 1, userInfo: nil))
            }
            if (studies.count > 0) {
                self.currentStudy = studies[0];
                AppDelegate.sharedInstance().setDebuggingUser(self.currentStudy?.patientId ?? "unknown")
            }
            return Promise(true);
        }

    }

    func setApiCredentials() {
        guard let currentStudy = currentStudy where gpsManager == nil else {
            return;
        }
        /* Setup APIManager's security */
        ApiManager.sharedInstance.password = PersistentPasswordManager.sharedInstance.passwordForStudy() ?? "";
        if let patientId = currentStudy.patientId {
            ApiManager.sharedInstance.patientId = patientId;
        }
    }
    func startStudyDataServices() {
        if gpsManager != nil {
            return;
        }
        setApiCredentials()
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
        setApiCredentials()
        let currentTime: Int64 = Int64(NSDate().timeIntervalSince1970);
        study.nextUploadCheck = currentTime + studySettings.uploadDataFileFrequencySeconds;
        study.nextSurveyCheck = currentTime + studySettings.checkForNewSurveysFreqSeconds;

        study.participantConsented = true;
        DataStorageManager.sharedInstance.setCurrentStudy(study)
        return Recline.shared.save(study).then { _ -> Promise<Bool> in
            return self.checkSurveys();
        }
    }

    func purgeStudies() -> Promise<Bool> {
        return firstly { _ -> Promise<[Study]> in
            return Recline.shared.queryAll()
            }.then { studies -> Promise<Bool> in
                var promise = Promise<Bool>(true)
                for study in studies {
                    promise = promise.then { _ in
                        return Recline.shared.purge(study)
                    }
                }
                return promise
        }
    }

    func leaveStudy() -> Promise<Bool> {

        /*
        guard let study = currentStudy else {
            return Promise(true);
        }
        */


        var promise: Promise<Void>
        if (gpsManager != nil) {
            promise = gpsManager!.stopAndClear()
        } else {
            promise = Promise();
        }


        UIApplication.sharedApplication().cancelAllLocalNotifications()
        return promise.then {
            self.gpsManager = nil;
                return self.purgeStudies().then { _ -> Promise<Bool> in
                let fileManager = NSFileManager.defaultManager()
                var enumerator = fileManager.enumeratorAtPath(DataStorageManager.uploadDataDirectory().path!);

                if let enumerator = enumerator {
                    while let filename = enumerator.nextObject() as? String {
                        if (true /*filename.hasSuffix(DataStorageManager.dataFileSuffix)*/) {
                            let filePath = DataStorageManager.uploadDataDirectory().URLByAppendingPathComponent(filename);
                            try fileManager.removeItemAtURL(filePath);
                        }
                    }
                }

                enumerator = fileManager.enumeratorAtPath(DataStorageManager.currentDataDirectory().path!);

                if let enumerator = enumerator {
                    while let filename = enumerator.nextObject() as? String {
                        if (true /* filename.hasSuffix(DataStorageManager.dataFileSuffix) */) {
                            let filePath = DataStorageManager.currentDataDirectory().URLByAppendingPathComponent(filename);
                            try fileManager.removeItemAtURL(filePath);
                        }
                    }
                }
                
                self.currentStudy = nil;
                
                return Promise(true);
                
            }
        }

    }

    func periodicNetworkTransfers() {
        guard let currentStudy = currentStudy where isHandlingPeriodic == false else {
            return;
        }

        // Good time to compact the database
        Recline.shared.compact().then { _ -> Void in
            if (!self.appDelegate.reachability!.isReachableViaWiFi()) {
                return;
            }

            let currentTime: Int64 = Int64(NSDate().timeIntervalSince1970);
            let nextSurvey = currentStudy.nextSurveyCheck ?? 0;
            let nextUpload = currentStudy.nextUploadCheck ?? 0;
            if (currentTime > nextSurvey) {
                self.setNextSurveyTime().then { _ -> Void in
                    self.isHandlingPeriodic = false;
                    self.checkSurveys();
                    }.error { _ -> Void in
                        log.error("Error checking for surveys");
                }
            }
            else if (currentTime > nextUpload) {
                self.setNextUploadTime().then { _ -> Void in
                    self.upload();
                    }.error { _ -> Void in
                        log.error("Error checking for uploads")
                }
            }

        }

    }

    func cleanupSurvey(activeSurvey: ActiveSurvey) {
        removeNotificationForSurvey(activeSurvey);
        if let surveyId = activeSurvey.survey?.surveyId {
            let timingsName = TrackingSurveyPresenter.timingDataType + "_" + surveyId;
            DataStorageManager.sharedInstance.closeStore(timingsName);
        }
    }

    func submitSurvey(activeSurvey: ActiveSurvey, surveyPresenter: TrackingSurveyPresenter? = nil) {
        if let survey = activeSurvey.survey, surveyId = survey.surveyId, surveyType = survey.surveyType where surveyType == .TrackingSurvey {
            var trackingSurvey: TrackingSurveyPresenter;
            if (surveyPresenter == nil) {
                trackingSurvey = TrackingSurveyPresenter(surveyId: surveyId, activeSurvey: activeSurvey, survey: survey)
                trackingSurvey.addTimingsEvent("expired", question: nil)
            } else {
                trackingSurvey = surveyPresenter!;
            }
            trackingSurvey.finalizeSurveyAnswers();
            if (activeSurvey.bwAnswers.count > 0) {
                if let surveyType = survey.surveyType {
                    switch (surveyType) {
                    case .AudioSurvey:
                        currentStudy?.submittedAudioSurveys = (currentStudy?.submittedAudioSurveys ?? 0) + 1;
                    case .TrackingSurvey:
                        currentStudy?.submittedTrackingSurveys = (currentStudy?.submittedTrackingSurveys ?? 0) + 1;

                    }
                }
            }
        }

        cleanupSurvey(activeSurvey);
    }

    func removeNotificationForSurvey(survey: ActiveSurvey) {
        guard let notification = survey.notification else {
            return;
        }

        log.info("Cancelling notification: \(notification.alertBody), \(notification.userInfo)")

        UIApplication.sharedApplication().cancelLocalNotification(notification);
        survey.notification = nil;
    }

    func updateActiveSurveys(forceSave: Bool = false) -> NSTimeInterval {
        log.info("Updating active surveys...")
        let currentDate = NSDate();
        let currentTime = currentDate.timeIntervalSince1970;
        let currentDay = calendar.component(.Weekday, fromDate: currentDate) - 1;
        let nowDateComponents = calendar.components([NSCalendarUnit.Day, NSCalendarUnit.Year, NSCalendarUnit.Month, NSCalendarUnit.TimeZone], fromDate: currentDate);
        nowDateComponents.hour = 0;
        nowDateComponents.minute = 0;
        nowDateComponents.second = 0;

        var closestNextSurveyTime: NSTimeInterval = currentTime + (60.0*60.0*24.0*7);

        guard let study = currentStudy, dayBegin = calendar.dateFromComponents(nowDateComponents)  else {
            return NSDate().dateByAddingTimeInterval((15.0*60.0)).timeIntervalSince1970;
        }


        var surveyDataModified = false;

        /* For all active surveys that aren't complete, but have expired, submit them */
        for (id, activeSurvey) in study.activeSurveys {
            if (!activeSurvey.isComplete && activeSurvey.expires > 0 && activeSurvey.expires <= currentTime) {
                log.info("ActiveSurvey \(id) expired.");
                activeSurvey.isComplete = true;
                surveyDataModified = true;
                submitSurvey(activeSurvey);
            }
        }

        var allSurveyIds: [String] = [ ];
        /* Now for each survey from the server, check on the scheduling */
        for survey in study.surveys {
            var next: Double = 0;
            /* Find the next scheduled date that is >= now */
            outer: for day in 0..<7 {
                let dayIdx = (day + currentDay) % 7;
                let timings = survey.timings[dayIdx].sort()

                for dayTime in timings {
                    let possibleNxt = dayBegin.dateByAddingTimeInterval((Double(day) * 24.0 * 60.0 * 60.0) + Double(dayTime)).timeIntervalSince1970;
                    if (possibleNxt > currentTime ) {
                        next = possibleNxt;
                        break outer
                    }
                }
            }
            if let id = survey.surveyId  {
                if (next > 0) {
                    closestNextSurveyTime = min(closestNextSurveyTime, next);
                }
                allSurveyIds.append(id);
                /* If we don't know about this survey already, add it in there */
                if study.activeSurveys[id] == nil && (survey.triggerOnFirstDownload || next > 0) {
                    log.info("Adding survey  \(id) to active surveys");
                    study.activeSurveys[id] = ActiveSurvey(survey: survey);
                    /* Schedule it for the next upcoming time, or immediately if triggerOnFirstDownload is true */
                    study.activeSurveys[id]?.expires = survey.triggerOnFirstDownload ? currentTime : next;
                    study.activeSurveys[id]?.isComplete = true;
                    log.info("Added survey \(id), expires: \(NSDate(timeIntervalSince1970: study.activeSurveys[id]!.expires))");
                    surveyDataModified = true;
                }
                if let activeSurvey = study.activeSurveys[id] {
                    /* If it's complete (including surveys we force-completed above) and it's expired, it's time for the next one */
                    if (activeSurvey.isComplete && activeSurvey.expires <= currentTime && activeSurvey.expires > 0) {
                        activeSurvey.reset();
                        activeSurvey.received = activeSurvey.expires;
                        let trackingSurvey: TrackingSurveyPresenter = TrackingSurveyPresenter(surveyId: id, activeSurvey: activeSurvey, survey: survey)
                        trackingSurvey.addTimingsEvent("notified", question: nil)

                        surveyDataModified = true;

                        /* Local notification goes here */

                        if let surveyType = survey.surveyType {
                            switch (surveyType) {
                            case .AudioSurvey:
                                currentStudy?.receivedAudioSurveys = (currentStudy?.receivedAudioSurveys ?? 0) + 1;
                            case .TrackingSurvey:
                                currentStudy?.receivedTrackingSurveys = (currentStudy?.receivedTrackingSurveys ?? 0) + 1;
                                
                            }

                            let localNotif = UILocalNotification();
                            localNotif.fireDate = currentDate;

                            var body: String;
                            switch(surveyType) {
                            case .TrackingSurvey:
                                body = "A new survey has arrived and is awaiting completion."
                            case .AudioSurvey:
                                body = "A new audio question has arrived and is awaiting completion."
                            }

                            localNotif.alertBody = body;
                            localNotif.soundName = UILocalNotificationDefaultSoundName;
                            localNotif.userInfo = [
                                "type": "survey",
                                "survey_type": surveyType.rawValue,
                                "survey_id": id
                            ];
                            log.info("Sending Survey notif: \(body), \(localNotif.userInfo)")
                            UIApplication.sharedApplication().scheduleLocalNotification(localNotif);
                            activeSurvey.notification = localNotif;

                        }

                    }
                    if (activeSurvey.expires != next) {
                        activeSurvey.expires = next;
                        surveyDataModified = true;
                    }
                }
            }
        }


        /* Set the badge, and remove surveys no longer on server from our active surveys list */
        var badgeCnt = 0;
        for (id, activeSurvey) in study.activeSurveys {
            if (activeSurvey.isComplete && !allSurveyIds.contains(id)) {
                cleanupSurvey(activeSurvey);
                study.activeSurveys.removeValueForKey(id);
                surveyDataModified = true;
            } else if (!activeSurvey.isComplete) {
                if (activeSurvey.expires > 0) {
                    closestNextSurveyTime = min(closestNextSurveyTime, activeSurvey.expires);
                }
                badgeCnt += 1;
            }
        }
        log.info("Badge Cnt: \(badgeCnt)");
        /*
        if (badgeCnt != study.lastBadgeCnt) {
            study.lastBadgeCnt = badgeCnt;
            surveyDataModified = true;
            let localNotif = UILocalNotification();
            localNotif.applicationIconBadgeNumber = badgeCnt;
            localNotif.fireDate = currentDate;
            UIApplication.sharedApplication().scheduleLocalNotification(localNotif);
        }
        */
        UIApplication.sharedApplication().applicationIconBadgeNumber = badgeCnt

        if (surveyDataModified || forceSave) {
            surveysUpdatedEvent.emit();
            Recline.shared.save(study).error { _ in
                log.error("Failed to save study after processing surveys");
            }
        }

        return closestNextSurveyTime;
    }

    func checkSurveys() -> Promise<Bool> {
        guard let study = currentStudy, studySettings = study.studySettings else {
            return Promise(false);
        }
        log.info("Checking for surveys...");
        study.nextSurveyCheck = Int64(NSDate().timeIntervalSince1970) + studySettings.checkForNewSurveysFreqSeconds;
        return Recline.shared.save(study).then { _ -> Promise<([Survey], Int)> in
                let surveyRequest = GetSurveysRequest();
                return ApiManager.sharedInstance.arrayPostRequest(surveyRequest);
            }.then { (surveys, _) in
                log.info("Surveys: \(surveys)");
                study.surveys = surveys;
                return Recline.shared.save(study).asVoid();
            }.then {
                self.updateActiveSurveys();
                return Promise(true);
            }.recover { _ -> Promise<Bool> in
                return Promise(false);
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

    func upload(surveysOnly: Bool = false) {
        if (isUploading) {
            return;
        }

        log.info("Checking for uploads...");

        var promiseChain: Promise<Bool>
        if (surveysOnly) {
            promiseChain = Promise(true);
        } else {
            promiseChain = setNextUploadTime();
        }

        promiseChain = promiseChain.then { _ in
            return DataStorageManager.sharedInstance.prepareForUpload().then {
                return Promise(true)
            };
        }

        var numFiles = 0;

        isUploading = true;

        return promiseChain.then { _ -> Promise<Bool> in
            let fileManager = NSFileManager.defaultManager()
            let enumerator = fileManager.enumeratorAtPath(DataStorageManager.uploadDataDirectory().path!);
            

            var uploadChain = Promise<Bool>(true)
            if let enumerator = enumerator {
                while let filename = enumerator.nextObject() as? String {
                    if (DataStorageManager.sharedInstance.isUploadFile(filename)) {
                        let filePath = DataStorageManager.uploadDataDirectory().URLByAppendingPathComponent(filename);
                        let uploadRequest = UploadRequest(fileName: filename, filePath: filePath.path!);
                        let promise: Promise<Bool> =
                            //ApiManager.sharedInstance.makePostRequest(uploadRequest).then { _ -> Promise<Bool> in
                            //ApiManager.sharedInstance.makeUploadRequest(uploadRequest, file: filePath).then { _ -> Promise<Bool> in

                            ApiManager.sharedInstance.makeMultipartUploadRequest(uploadRequest, file: filePath).then { _ -> Promise<Bool> in
                            log.info("Finished uploading: \(filename), removing.");
                            try fileManager.removeItemAtURL(filePath);
                            return Promise(true);
                        }
                        uploadChain = uploadChain.then {_ in
                            return promise;
                        }
                        numFiles = numFiles + 1;
                        //promises.append(promise);
                    }
                }
            }
            return uploadChain
        }.then { results -> Void in
            log.info("OK uploading \(numFiles). \(results)");
            self.isUploading = false;
            }.error { error in
                log.error("Error uploading: \(error)");
                self.isUploading = false;
        }
    }
}