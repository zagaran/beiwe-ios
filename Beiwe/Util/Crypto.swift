//
//  Crypto.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/25/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import IDZSwiftCommonCrypto

class Crypto {
    static let sharedInstance = Crypto();
    private static let defaultRSAPadding: SecPadding = .PKCS1


    func sha256Base64URL(str: String) -> String {
        let sha256: Digest = Digest(algorithm: .SHA256);
        sha256.update(str);
        let digest = sha256.final();
        let data = NSData(bytes: digest, length: digest.count);
        let base64Str = data.base64EncodedStringWithOptions([]);
        return base64ToBase64URL(base64Str);
    }

    func base64ToBase64URL(base64str: String) -> String {
        //        //replaceAll('/', '_').replaceAll('+', '-');
        return base64str.stringByReplacingOccurrencesOfString("/", withString: "_")
            .stringByReplacingOccurrencesOfString("+", withString: "-");
    }

    func randomBytes(length: Int) -> NSData? {
        let data: NSMutableData! = NSMutableData(length: Int(length))
        let result = SecRandomCopyBytes(kSecRandomDefault, length, UnsafeMutablePointer<UInt8>(data.mutableBytes))
        return (result == 0) ? data : nil;
    }

    func newAesKey(keyLength: Int = 128) -> NSData? {
        let length = (keyLength+7) / 8;
        return randomBytes(length);
    }


    func rsaEncryptString(str: String, publicKey: SecKeyRef, padding: SecPadding = defaultRSAPadding) throws -> String {
        let blockSize = SecKeyGetBlockSize(publicKey)
        let plainTextData = [UInt8](str.utf8)
        let plainTextDataLength = Int(str.characters.count)
        var encryptedData = [UInt8](count: Int(blockSize), repeatedValue: 0)
        var encryptedDataLength = blockSize

        let status = SecKeyEncrypt(publicKey, padding, plainTextData, plainTextDataLength, &encryptedData, &encryptedDataLength)
        if status != noErr {
            throw NSError(domain: "beiwe.crypto", code: 1, userInfo: [:]);
        }

        let data = NSData(bytes: encryptedData, length: encryptedDataLength)
        return base64ToBase64URL(data.base64EncodedStringWithOptions([]));
    }

    func aesEncrypt(iv: NSData, key: NSData, plainText: String) -> NSData? {
        let arrayKey = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(key.bytes), count: key.length));
        let arrayIv = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(iv.bytes), count: iv.length));

        let cryptor = Cryptor(operation:.Encrypt, algorithm:.AES, options: .PKCS7Padding, key:arrayKey, iv: arrayIv)
        let cipherText = cryptor.update(plainText)?.final()
        if let cipherText = cipherText {
            return NSData(bytes: cipherText, length: cipherText.count);
        }
        return nil;
    }

}