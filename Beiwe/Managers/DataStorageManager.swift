//
//  DataStorageManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/29/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import Security

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

    init(type: String, headers: [String], patientId: String, publicKey: String) {
        self.patientId = patientId;
        self.publicKey = publicKey;
        self.type = type;
        self.headers = headers;

        reset();
    }

    func reset() {
        let name = patientId + "_" + type + "_" + String(Int(NSDate().timeIntervalSince1970 * 1000));
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


    func _writeLine(line: String) {
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

    func writeLine(line: String) {
        hasData = true;
        dataPoints = dataPoints + 1;
        _writeLine(line);
    }

    func store(data: [String]) {
        var sanitizedData: [String] = [];
        for str in data {
            sanitizedData.append(str.stringByReplacingOccurrencesOfString(",", withString: ";").stringByReplacingOccurrencesOfString("[\t\n\r]", withString: " ", options: .RegularExpressionSearch))
        }
        let csv = sanitizedData.joinWithSeparator(DataStorage.delimiter);
        writeLine(csv)

    }

    func flush() {
        if (!hasData || lines.count == 0) {
            return;
        }
        let data = lines.joinWithSeparator("").dataUsingEncoding(NSUTF8StringEncoding);
        if let filename = filename, data = data  {
            let fileManager = NSFileManager.defaultManager();
            if (!fileManager.fileExistsAtPath(filename.path!)) {
                if (!fileManager.createFileAtPath(filename.path!, contents: data, attributes: nil)) {
                    hasError = true;
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
                    bytesWritten = bytesWritten + data.length;
                    print("Appended data to file: \(filename)");
                    if (bytesWritten > DataStorageManager.MAX_DATAFILE_SIZE) {
                        reset();
                    }
                } else {
                    hasError = true;
                    print("Error opening file for writing");
                }
            }
        } else {
            print("No filename.  NO data??");
            hasError = true;
            reset();
        }
        lines = [ ];
    }

    func closeAndReset() {
        if (hasData) {
            flush();
        }
        reset();
    }
}

class DataStorageManager {
    static let sharedInstance = DataStorageManager();
    static let dataFileSuffix = ".csv";
    static let MAX_DATAFILE_SIZE = (1024 * 1024) * 10; // 10Meg

    var publicKey: String?;
    var storageTypes: [String: DataStorage] = [:];
    var study: Study?;

    func store(type: String, headers: [String], data: [String]) {
        if (storageTypes[type] == nil) {
            if let publicKey = publicKey, patientId = study?.patientId {
                storageTypes[type] = DataStorage(type: type, headers: headers, patientId: patientId, publicKey: publicKey);
            } else {
                print("No public key found! Can't store data");
                return;
            }
        }
        let storage = storageTypes[type]!;
        let csv = data.joinWithSeparator(DataStorage.delimiter);
        storage.writeLine(csv)
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

    func flush(type: String) {
        if let storage = storageTypes[type] {
            storage.flush();
        }

    }

    func closeStore(type: String) {
        if let storage = storageTypes[type] {
            storage.flush();
            storageTypes.removeValueForKey(type);
        }
    }


    func setCurrentStudy(study: Study) {
        self.study = study;
        if let publicKey = study.studySettings?.clientPublicKey {
            self.publicKey = publicKey
        }
    }

    func flushAll() {
        for (_, storage) in storageTypes {
            storage.closeAndReset();
        }
    }

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

    func prepareForUpload() {
        flushAll();
        /* Move out of currentdata into uploaddata */

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
    }
}