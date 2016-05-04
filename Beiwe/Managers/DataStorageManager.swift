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
import IDZSwiftCommonCrypto

enum DataStorageErrors : ErrorType {
    case CantCreateFile
    case NotInitialized

}
class EncryptedStorage {

    static let delimiter = ",";

    let keyLength = 128;

    var type: String;
    var aesKey: NSData?;
    var iv: NSData?
    var publicKey: String;
    var filename: NSURL;
    var realFilename: NSURL
    var patientId: String;
    let queue: dispatch_queue_t
    var currentData: NSMutableData = NSMutableData()
    var hasData = false
    var handle: NSFileHandle?
    let fileManager = NSFileManager.defaultManager();
    var sc: StreamCryptor


    init(type: String, suffix: String, patientId: String, publicKey: String) {
        self.patientId = patientId;
        self.publicKey = publicKey;
        self.type = type;

        queue = dispatch_queue_create("com.rocketfarm.beiwe.dataqueue." + type, nil)

        let name = patientId + "_" + type + "_" + String(Int64(NSDate().timeIntervalSince1970 * 1000));
        realFilename = DataStorageManager.currentDataDirectory().URLByAppendingPathComponent(name + suffix)
        filename = NSURL(fileURLWithPath:  NSTemporaryDirectory()).URLByAppendingPathComponent(name + suffix)
        aesKey = Crypto.sharedInstance.newAesKey(keyLength);
        iv = Crypto.sharedInstance.randomBytes(16)
        let arrayKey = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(aesKey!.bytes), count: aesKey!.length));
        let arrayIv = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(iv!.bytes), count: iv!.length));
        sc = StreamCryptor(operation: .Encrypt, algorithm: .AES, options: .PKCS7Padding, key: arrayKey, iv: arrayIv)

    }

    func open() -> Promise<Void> {
        guard let aesKey = aesKey, iv = iv else {
            return Promise(error: DataStorageErrors.NotInitialized)
        }
        return Promise().then(on: queue) {
            if (!self.fileManager.createFileAtPath(self.filename.path!, contents: nil, attributes: nil)) {
                return Promise(error: DataStorageErrors.CantCreateFile)
            } else {
                print("Create new enc file: \(self.filename)");
            }
            self.handle = try? NSFileHandle(forWritingToURL: self.filename)
            let rsaLine = try Crypto.sharedInstance.base64ToBase64URL(SwiftyRSA.encryptString(Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedStringWithOptions([])), publicKeyId: PersistentPasswordManager.sharedInstance.publicKeyName(), padding: .None)) + "\n";
            self.handle?.writeData(rsaLine.dataUsingEncoding(NSUTF8StringEncoding)!)
            let ivHeader = Crypto.sharedInstance.base64ToBase64URL(iv.base64EncodedStringWithOptions([])) + ":"
            self.handle?.writeData(ivHeader.dataUsingEncoding(NSUTF8StringEncoding)!)
            return Promise()
        }


    }

    func close() -> Promise<Void> {
        return write(nil, writeLen: 0, isFlush: true).then(on: queue) {
            if let handle = self.handle {
                handle.closeFile()
                self.handle = nil
                try NSFileManager.defaultManager().moveItemAtURL(self.filename, toURL: self.realFilename)
                print("moved temp data file \(self.filename) to \(self.realFilename)");
            }
            return Promise()
        }
    }

    func _write(data: NSData, len: Int) -> Promise<Int> {
        if (len == 0) {
            return Promise(0);
        }
        return Promise().then(on: queue) {
            self.hasData = true
            self.handle?.writeData(data)
            return Promise(len)
        }

    }

    func write(data: NSData?, writeLen: Int, isFlush: Bool = false) -> Promise<Void> {
        return Promise().then(on: queue) {
            if (data != nil && writeLen != 0) {
                // Need to encrypt data
                let encryptLen = self.sc.getOutputLength(writeLen)
                let bufferOut = UnsafeMutablePointer<Void>.alloc(encryptLen)
                var byteCount: Int = 0
                let bufferIn = UnsafeMutablePointer<Void>(data!.bytes)
                self.sc.update(bufferIn, byteCountIn: writeLen, bufferOut: bufferOut, byteCapacityOut: encryptLen, byteCountOut: &byteCount)
                self.currentData.appendData(NSData(bytesNoCopy: bufferOut, length: byteCount))
            }
            if (isFlush) {
                let encryptLen = self.sc.getOutputLength(0, isFinal: true)
                if (encryptLen > 0) {
                    let bufferOut = UnsafeMutablePointer<Void>.alloc(encryptLen)
                    var byteCount: Int = 0
                    self.sc.final(bufferOut, byteCapacityOut: encryptLen, byteCountOut: &byteCount)
                    self.currentData.appendData(NSData(bytesNoCopy: bufferOut, length: byteCount))
                }
            }
            // Only write multiples of 3, since we are base64 encoding and would otherwise end up with padding
            var writeLen: Int
            if (isFlush) {
                writeLen = self.currentData.length
            } else {
                writeLen = (self.currentData.length / 3) * 3
            }
            return self._write(self.currentData, len: writeLen)
            }.then(on: queue) { writeLen in
                self.currentData.replaceBytesInRange(NSRange(0..<writeLen), withBytes: nil, length: 0)
        }
    }

    deinit {
        if (handle != nil) {
            handle?.closeFile()
            handle = nil
        }
    }
}

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
    var realFilename: NSURL?
    var dataPoints = 0;
    var patientId: String;
    var bytesWritten = 0;
    var hasError = false;
    var noBuffer = false;
    var sanitize = false;
    let moveOnClose: Bool
    let queue: dispatch_queue_t


    init(type: String, headers: [String], patientId: String, publicKey: String, moveOnClose: Bool = false) {
        self.patientId = patientId;
        self.publicKey = publicKey;
        self.type = type;
        self.headers = headers;
        self.moveOnClose = moveOnClose

        queue = dispatch_queue_create("com.rocketfarm.beiwe.dataqueue." + type, nil)
        reset();
    }

    private func reset() {
        if let filename = filename, realFilename = realFilename where moveOnClose == true && hasData == true {
            do {
                try NSFileManager.defaultManager().moveItemAtURL(filename, toURL: realFilename)
                print("moved temp data file \(filename) to \(realFilename)");
            } catch {
                print("Error moving temp data \(filename) to \(realFilename)");
            }
        }
        let name = patientId + "_" + type + "_" + String(Int64(NSDate().timeIntervalSince1970 * 1000));
        realFilename = DataStorageManager.currentDataDirectory().URLByAppendingPathComponent(name + DataStorageManager.dataFileSuffix)
        if (moveOnClose) {
            filename = NSURL(fileURLWithPath:  NSTemporaryDirectory()).URLByAppendingPathComponent(name + DataStorageManager.dataFileSuffix) ;
        } else {
            filename = realFilename
        }
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
                        fileHandle.closeFile()
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
            var promise = Promise()
            if (self.hasData) {
                promise = promise.then { return self.flush(); }
            }
            return promise.then {
                return self.reset()
            }
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

    

    func isUploadFile(filename: String) -> Bool {
        return filename.hasSuffix(DataStorageManager.dataFileSuffix) || filename.hasSuffix(".mp4") || filename.hasSuffix(".wav")
    }
    func prepareForUpload() -> Promise<Void> {
        return self._flushAll().then(on: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {

                let fileManager = NSFileManager.defaultManager()
                let enumerator = fileManager.enumeratorAtPath(DataStorageManager.currentDataDirectory().path!);

                if let enumerator = enumerator {
                    while let filename = enumerator.nextObject() as? String {
                        if (self.isUploadFile(filename)) {
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