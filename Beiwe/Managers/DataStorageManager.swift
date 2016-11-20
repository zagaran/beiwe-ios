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
        realFilename = DataStorageManager.currentDataDirectory().URLByAppendingPathComponent(name + suffix)!
        filename = NSURL(fileURLWithPath:  NSTemporaryDirectory()).URLByAppendingPathComponent(name + suffix)!
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
            if (!self.fileManager.createFileAtPath(self.filename.path!, contents: nil, attributes: [NSFileProtectionKey: NSFileProtectionNone])) {
                return Promise(error: DataStorageErrors.CantCreateFile)
            } else {
                log.info("Create new enc file: \(self.filename)");
            }
            self.handle = try? NSFileHandle(forWritingToURL: self.filename)
            let rsaLine = try Crypto.sharedInstance.base64ToBase64URL(SwiftyRSA.encryptString(Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedStringWithOptions([])), publicKeyId: PersistentPasswordManager.sharedInstance.publicKeyName(self.patientId), padding: .None)) + "\n";
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
                log.info("moved temp data file \(self.filename) to \(self.realFilename)");
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
            let dataToWriteBuffer = UnsafeMutablePointer<Void>(data.bytes)
            let dataToWrite = NSData(bytesNoCopy: dataToWriteBuffer, length: len, freeWhenDone: false)
            let encodedData: String = Crypto.sharedInstance.base64ToBase64URL(dataToWrite.base64EncodedStringWithOptions([]))
            self.handle?.writeData(encodedData.dataUsingEncoding(NSUTF8StringEncoding)!)
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
                    let finalData = NSData(bytesNoCopy: bufferOut, length: byteCount);

                    let count = finalData.length / sizeof(UInt8)

                    // create array of appropriate length:
                    var array = [UInt8](count: count, repeatedValue: 0)

                    // copy bytes into array
                    finalData.getBytes(&array, length:count * sizeof(UInt8))
                    self.currentData.appendData(finalData)
                }
            }
            // Only write multiples of 3, since we are base64 encoding and would otherwise end up with padding
            var evenLength: Int
            if (isFlush) {
                evenLength = self.currentData.length
            } else {
                evenLength = (self.currentData.length / 3) * 3
            }
            return self._write(self.currentData, len: evenLength)
            }.then(on: queue) { evenLength in
                self.currentData.replaceBytesInRange(NSRange(0..<evenLength), withBytes: nil, length: 0)
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
                log.info("moved temp data file \(filename) to \(realFilename)");
            } catch {
                log.error("Error moving temp data \(filename) to \(realFilename)");
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
        if let aesKey = aesKey {
            do {
                let b64aes = Crypto.sharedInstance.base64ToBase64URL(aesKey.base64EncodedStringWithOptions([]))
                //log.info("B64Aes for \(realFilename!): \(b64aes)")
                let rsaLine = try Crypto.sharedInstance.base64ToBase64URL(SwiftyRSA.encryptString(b64aes, publicKeyId: PersistentPasswordManager.sharedInstance.publicKeyName(self.patientId), padding: .None)) + "\n";
                lines = [ rsaLine ];
                //log.info("RSALine: \(rsaLine)")
                _writeLine(headers.joinWithSeparator(DataStorage.delimiter))
            } catch {
                log.error("Failed to RSA encrypt AES key")
                hasError = true;
            }
        } else {
            log.error("Failed to generate AES key")
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
                    flush(false);
                }
            }
        } else {
            log.error("Can't generate IV, skipping data");
            hasError = true;
        }
    }

    private func writeLine(line: String) {
        hasData = true;
        dataPoints = dataPoints + 1;
        _writeLine(line);
        if (noBuffer) {
            flush(false);
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

    func flush(reset: Bool = false) -> Promise<Void> {
        return Promise().then(on: queue) {
            if (!self.hasData || self.lines.count == 0) {
                if (reset) {
                    self.reset()
                }
                return Promise();
            }
            let data = self.lines.joinWithSeparator("").dataUsingEncoding(NSUTF8StringEncoding);
            self.lines = [ ];
            if let filename = self.filename, data = data  {
                let fileManager = NSFileManager.defaultManager();
                if (!fileManager.fileExistsAtPath(filename.path!)) {
                    if (!fileManager.createFileAtPath(filename.path!, contents: data, attributes: [NSFileProtectionKey: NSFileProtectionNone])) {
                        self.hasError = true;
                        log.error("Failed to create file.");
                    } else {
                        log.info("Create new data file: \(filename)");
                    }
                } else {
                    if let fileHandle = try? NSFileHandle(forWritingToURL: filename) {
                        defer {
                            fileHandle.closeFile()
                        }
                        let seekPos = fileHandle.seekToEndOfFile()
                        fileHandle.writeData(data)
                        fileHandle.closeFile()
                        self.bytesWritten = self.bytesWritten + data.length;
                        log.info("Appended data to file: \(filename), size: \(seekPos)");
                        if (self.bytesWritten > DataStorageManager.MAX_DATAFILE_SIZE) {
                            log.info("Rolling data file: \(filename)")
                            self.reset();
                        }
                    } else {
                        self.hasError = true;
                        log.error("Error opening file for writing");
                    }
                }
            } else {
                print("No filename.  NO data??");
                self.hasError = true;
                self.reset();
            }
            if (reset) {
                self.reset()
            }
            return Promise()
        }
    }

    func closeAndReset() -> Promise<Void> {
        return flush(true)
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
        return NSURL(fileURLWithPath: cacheDir).URLByAppendingPathComponent("currentdata")!;
    }

    static func uploadDataDirectory() -> NSURL {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.CachesDirectory,
                                                           .UserDomainMask, true)

        let cacheDir = dirPaths[0]
        return NSURL(fileURLWithPath: cacheDir).URLByAppendingPathComponent("uploaddata")!;
    }

    func createDirectories() {


        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(DataStorageManager.currentDataDirectory().path!,
                                                                     withIntermediateDirectories: true,
                                                                     attributes: [NSFileProtectionKey: NSFileProtectionNone]);
            try NSFileManager.defaultManager().createDirectoryAtPath(DataStorageManager.uploadDataDirectory().path!,
                                                                     withIntermediateDirectories: true,
                                                                     attributes: [NSFileProtectionKey: NSFileProtectionNone])
        } catch {
            log.error("Failed to create directories.");
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
                log.error("No public key found! Can't store data");
                return nil;
            }
        }
        return storageTypes[type]!;
    }

    func closeStore(type: String) -> Promise<Void> {
        if let storage = storageTypes[type] {
            self.storageTypes.removeValueForKey(type);
            return storage.flush(false);
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

    func _printFileInfo(file: NSURL) {
        let path = file.path!
        var seekPos: UInt64 = 0
        var firstLine: String = ""
        log.info("infoBeginForFile: \(path)")
        if let fileHandle = try? NSFileHandle(forReadingFromURL: file) {
            defer {
                fileHandle.closeFile()
            }
            let dataString = String(data: fileHandle.readDataOfLength(2048), encoding: NSUTF8StringEncoding)
            let dataArray = dataString?.characters.split{$0 == "\n"}.map(String.init)
            if let dataArray = dataArray where dataArray.count > 0 {
                firstLine = dataArray[0]
            } else {
                log.warning("No first line found!!")
            }
            seekPos = fileHandle.seekToEndOfFile()
            fileHandle.closeFile()
        } else {
            log.error("Error opening file: \(path) for info");
        }

        log.info("infoForFile: len: \(seekPos), line: \(firstLine), filename: \(path)")


    }
    func _moveFile(src: NSURL, dst: NSURL) {
        let fileManager = NSFileManager.defaultManager()
        do {
            //_printFileInfo(src)
            try fileManager.moveItemAtURL(src, toURL: dst)
            //_printFileInfo(dst)
            log.info("moved \(src) to \(dst)");
        } catch {
            log.error("Error moving \(src) to \(dst)");
        }
    }
    func prepareForUpload() -> Promise<Void> {
        // self._flushAll()
        let prepQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        var filesToUpload: [String] = [ ]
        /* Flush once to get all of the files currently processing */
        return self._flushAll().then(on: prepQ) {
            /* And record there names */
            let fileManager = NSFileManager.defaultManager()

                let enumerator = fileManager.enumeratorAtPath(DataStorageManager.currentDataDirectory().path!);

                if let enumerator = enumerator {
                    while let filename = enumerator.nextObject() as? String {
                        if (self.isUploadFile(filename)) {
                            filesToUpload.append(filename)
                        } else {
                            log.warning("Non upload file sitting in directory: \(filename)")
                        }
                    }
                }
                /* Need to flush again, because there is (very slim) one of those files was created after the flush */
                return self._flushAll()
            }.then(on: prepQ) {
                for filename in filesToUpload {
                    let src = DataStorageManager.currentDataDirectory().URLByAppendingPathComponent(filename);
                    let dst = DataStorageManager.uploadDataDirectory().URLByAppendingPathComponent(filename);
                    self._moveFile(src!, dst: dst!)
                }
                return Promise()
        }
    }
}
