//
//  DataStorageManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/29/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import Security
import PromiseKit

class DataStorage {

    static let delimiter = ",";

    let flushLines = 100;
    let keyLength = 128;

    var headers: [String];
    var type: String;
    var lines: [String] = [ ];
    var aesKey: NSData?;
    var publicKey: String;
    var hasData: Bool = false;
    var filename: NSURL?;
    var dataPoints = 0;
    var patientId: String;
    var bytesWritten = 0;
    var hasError = false;
    var noBuffer = false;
    var sanitize = false;
    let queue: dispatch_queue_t


    init(type: String, headers: [String], patientId: String, publicKey: String) {
        self.patientId = patientId;
        self.publicKey = publicKey;
        self.type = type;
        self.headers = headers;

        queue = dispatch_queue_create("com.rocketfarm.beiwe.dataqueue." + type, nil)
        reset();
    }

    private func reset() {
        let name = patientId + "_" + type + "_" + String(Int64(NSDate().timeIntervalSince1970 * 1000));
        filename = DataStorageManager.currentDataDirectory().URLByAppendingPathComponent(name + DataStorageManager.dataFileSuffix) ;
        lines = [ ];
        dataPoints = 0;
        bytesWritten = 0;
        hasData = false;
        aesKey = Crypto.sharedInstance.newAesKey(keyLength);
        print("Generating new file and RSA key!");
        if let aesKey = aesKey {
            do {
                let rsaLine = try Crypto.sharedInstance.base64ToBase64URL(SwiftyRSA.encryptString(Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedStringWithOptions([])), publicKeyId: PersistentPasswordManager.sharedInstance.publicKeyName(), padding: .None)) + "\n";
                lines = [ rsaLine ];
                _writeLine(headers.joinWithSeparator(DataStorage.delimiter))
            } catch {
                print("Failed to RSA encrypt AES key")
                hasError = true;
            }
        } else {
            print("Failed to generate AES key")
            hasError = true;
        }
    }


    private func _writeLine(line: String) {
        let iv: NSData? = Crypto.sharedInstance.randomBytes(16);
        if let iv = iv, aesKey = aesKey {
            let encrypted = Crypto.sharedInstance.aesEncrypt(iv, key: aesKey, plainText: line);
            if let encrypted = encrypted  {
                lines.append(Crypto.sharedInstance.base64ToBase64URL(iv.base64EncodedStringWithOptions([])) + ":" + Crypto.sharedInstance.base64ToBase64URL(encrypted.base64EncodedStringWithOptions([])) + "\n")
                if (lines.count >= flushLines) {
                    flush();
                }
            }
        } else {
            print("Can't generate IV, skipping data");
            hasError = true;
        }
    }

    private func writeLine(line: String) {
        hasData = true;
        dataPoints = dataPoints + 1;
        _writeLine(line);
        if (noBuffer) {
            flush();
        }
    }

    func store(data: [String]) -> Promise<Void> {
        return Promise().then(on: queue) {
            var sanitizedData: [String];
            if (self.sanitize) {
                sanitizedData = [];
                for str in data {
                    sanitizedData.append(str.stringByReplacingOccurrencesOfString(",", withString: ";").stringByReplacingOccurrencesOfString("[\t\n\r]", withString: " ", options: .RegularExpressionSearch))
                }
            } else {
                sanitizedData = data;
            }
            let csv = sanitizedData.joinWithSeparator(DataStorage.delimiter);
            self.writeLine(csv)
            return Promise()
        }
    }

    func flush() -> Promise<Void> {
        return Promise().then(on: queue) {
            if (!self.hasData || self.lines.count == 0) {
                return Promise();
            }
            let data = self.lines.joinWithSeparator("").dataUsingEncoding(NSUTF8StringEncoding);
            if let filename = self.filename, data = data  {
                let fileManager = NSFileManager.defaultManager();
                if (!fileManager.fileExistsAtPath(filename.path!)) {
                    if (!fileManager.createFileAtPath(filename.path!, contents: data, attributes: nil)) {
                        self.hasError = true;
                        print("Failed to create file.");
                    } else {
                        print("Create new data file: \(filename)");
                    }
                } else {
                    if let fileHandle = try? NSFileHandle(forWritingToURL: filename) {
                        defer {
                            fileHandle.closeFile()
                        }
                        fileHandle.seekToEndOfFile()
                        fileHandle.writeData(data)
                        self.bytesWritten = self.bytesWritten + data.length;
                        print("Appended data to file: \(filename)");
                        if (self.bytesWritten > DataStorageManager.MAX_DATAFILE_SIZE) {
                            self.reset();
                        }
                    } else {
                        self.hasError = true;
                        print("Error opening file for writing");
                    }
                }
            } else {
                print("No filename.  NO data??");
                self.hasError = true;
                self.reset();
            }
            self.lines = [ ];
            return Promise()
        }
    }

    func closeAndReset() -> Promise<Void> {
        return Promise().then(on: queue) {
            if (self.hasData) {
                self.flush();
            }
            self.reset();
            return Promise()
        }
    }
}

class DataStorageManager {
    static let sharedInstance = DataStorageManager();
    static let dataFileSuffix = ".csv";
    static let MAX_DATAFILE_SIZE = (1024 * 1024) * 10; // 10Meg

    var publicKey: String?;
    var storageTypes: [String: DataStorage] = [:];
    var study: Study?;

    static func currentDataDirectory() -> NSURL {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.CachesDirectory,
                                                           .UserDomainMask, true)

        let cacheDir = dirPaths[0]
        return NSURL(fileURLWithPath: cacheDir).URLByAppendingPathComponent("currentdata");
    }

    static func uploadDataDirectory() -> NSURL {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.CachesDirectory,
                                                           .UserDomainMask, true)

        let cacheDir = dirPaths[0]
        return NSURL(fileURLWithPath: cacheDir).URLByAppendingPathComponent("uploaddata");
    }

    func createDirectories() {


        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(DataStorageManager.currentDataDirectory().path!,
                                                                     withIntermediateDirectories: true,
                                                                     attributes: nil);
            try NSFileManager.defaultManager().createDirectoryAtPath(DataStorageManager.uploadDataDirectory().path!,
                                                                     withIntermediateDirectories: true,
                                                                     attributes: nil)
        } catch {
            print("Failed to create directories.");
        }
    }

    func setCurrentStudy(study: Study) {
        self.study = study;
        if let publicKey = study.studySettings?.clientPublicKey {
            self.publicKey = publicKey
        }
    }

    func createStore(type: String, headers: [String]) -> DataStorage? {
        if (storageTypes[type] == nil) {
            if let publicKey = publicKey, patientId = study?.patientId {
                storageTypes[type] = DataStorage(type: type, headers: headers, patientId: patientId, publicKey: publicKey);
            } else {
                print("No public key found! Can't store data");
                return nil;
            }
        }
        return storageTypes[type]!;
    }

    func closeStore(type: String) -> Promise<Void> {
        if let storage = storageTypes[type] {
            self.storageTypes.removeValueForKey(type);
            return storage.flush();
        }
        return Promise();
    }


    func _flushAll() -> Promise<Void> {
        var promises: [Promise<Void>] = []
        for (_, storage) in storageTypes {
            promises.append(storage.closeAndReset());
        }
        return when(promises)
    }

    func prepareForUpload() -> Promise<Void> {
        return self._flushAll().then(on: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {

                let fileManager = NSFileManager.defaultManager()
                let enumerator = fileManager.enumeratorAtPath(DataStorageManager.currentDataDirectory().path!);

                if let enumerator = enumerator {
                    while let filename = enumerator.nextObject() as? String {
                        if (filename.hasSuffix(DataStorageManager.dataFileSuffix)) {
                            let src = DataStorageManager.currentDataDirectory().URLByAppendingPathComponent(filename);
                            let dst = DataStorageManager.uploadDataDirectory().URLByAppendingPathComponent(filename);
                            do {
                                try fileManager.moveItemAtURL(src, toURL: dst)
                                print("moved \(src) to \(dst)");
                            } catch {
                                print("Error moving \(src) to \(dst)");
                            }
                        }
                    }
                    /*
                     for filename in enumerator.allObjects {
                     }*/
                }
                return Promise();
        }
    }
}