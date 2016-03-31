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
        if (studySettings.gps) {
            gpsManager!.addDataService(studySettings.gpsOnDurationSeconds, off: studySettings.gpsOffDurationSeconds, handler: gpsManager!)
        }
        gpsManager!.startGpsAndTimer();
    }

    func upload() {
        if (isUploading) {
            return;
        }

        DataStorageManager.sharedInstance.prepareForUpload();

        let fileManager = NSFileManager.defaultManager()
        let enumerator = fileManager.enumeratorAtPath(DataStorageManager.uploadDataDirectory().path!);

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

    }
}