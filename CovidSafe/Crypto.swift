//
//  Crypto.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import CommonCrypto
import Foundation
import Security

enum SecurityError: Error {
    case PublicKeyCopyError
    case EncryptionFailedError(_ status: CCCryptorStatus)
    case DigestFailedError
    case EncryptionLengthError
    case EncryptionKeyLengthError
    case UnexpectedNilKeys
}


class Crypto {
    private static var cachedExportPublicKey: Data?
    private static var cachedAesKey: Data?
    private static var cachedMacKey: Data?
    private static var keyGenTime: Int64 = Int64.min
    private static var counter: UInt16 = 0
    private static let NONCE_PADDING: Data = Data([UInt8](repeating: UInt8(0x0E), count: 14))
    private static let keyCacheQueue = DispatchQueue(label: "au.gov.health.covidsafe.crypto")
    private static let KEY_GEN_TIME_DELTA: Int64 = 450  // 7.5 minutes
    #if DEBUG
    private static let publicKey = Data(base64Encoded: "BNrAcR+C6nkCpIYS9KWYt0Z5Sbleh7UybHmIT2T9YzuR9RzTh3YZcMBjr1K6smeDJW7sPCvMFJNWVPkk3exqjkQ=")
    #else
    private static let publicKey = Data(base64Encoded: "BDQbOM4lxeK6ed9br26qvcwsYgaUK9w3CozIHP1gOhR7+qwb7vrh0kSSUUtsayekard9EHElA9RNn/3dJW9hr7I=")
    #endif
    
    /**
     Get a series of secrets that can be decrypted by the server key. The returned data is:
     1. the ephemeral public key used for decrypting
     2. the AES encryption key
     3. the HMAC signature key
     4. the IV for AES encryption
     - Parameter serverKey: X9.63  formatted P-256 public key for the server
     - Throws: Errors from Security framework, or `SecurityError.PublicKeyCopyError`
     if function failed to derive public key from the ephemeral private key
     - Returns:
     - publicKey: exported public P-256 key (compressed form)
     - aesKey: ephemeral 16-byte AES-128 key
     - macKey: ephemeral 16-byte key for HMAC
     - iv: ephemeral 16-byte AES-128 IV
     */
    private static func getEphemeralSecrets(_ serverKey: Data) throws -> (publicKey: Data, aesKey: Data, macKey: Data) {
        // Server public key
        var err: Unmanaged<CFError>?
        let serverKeyOptions: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
        ]
        guard let serverPublicKey = SecKeyCreateWithData(serverKey as CFData, serverKeyOptions as CFDictionary, &err) else {
            throw err!.takeRetainedValue() as Error
        }
        
        // CREATE A LOCAL EPHEMERAL P-256 KEYPAIR
        let ephemeralPublicKeyAttributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
        ]
        
        guard let ephemeralPrivateKey = SecKeyCreateRandomKey(ephemeralPublicKeyAttributes as CFDictionary, &err) else {
            throw err!.takeRetainedValue() as Error
        }
        guard let ephemeralPublicKey = SecKeyCopyPublicKey(ephemeralPrivateKey) else {
            throw SecurityError.PublicKeyCopyError
        }
        
        // Exported ephemeral public key for sending/MACing later (compressed format, per ANSI X9.62)
        let exportPublicKey = try ephemeralPublicKey.CopyCompressedECPublicKey()
        
        // COMPUTE SHARED SECRET
        let params = [SecKeyKeyExchangeParameter.requestedSize.rawValue: 32]
        guard let sharedSecret = SecKeyCopyKeyExchangeResult(ephemeralPrivateKey,
                                                             SecKeyAlgorithm.ecdhKeyExchangeStandard,
                                                             serverPublicKey,
                                                             params as CFDictionary,
                                                             &err) as Data? else {
                                                                throw err!.takeRetainedValue() as Error
        }
        
        // KDF THE SHARED SECRET TO GET ENC KEY, MAC KEY
        var keysHashCtx = CC_SHA256_CTX()
        
        // For keys we'll be using SHA256(sharedSecret)
        var res: Int32
        var keysHashValue = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Init(&keysHashCtx)
        res = sharedSecret.withUnsafeBytes {
            return CC_SHA256_Update(&keysHashCtx, $0.baseAddress, CC_LONG(sharedSecret.count))
        }
        guard res == 1 else { throw SecurityError.DigestFailedError }
        res = keysHashValue.withUnsafeMutableBytes {
            return CC_SHA256_Final($0.bindMemory(to: UInt8.self).baseAddress, &keysHashCtx)
        }
        guard res == 1 else { throw SecurityError.DigestFailedError }
        
        // Form the keys
        let aesKey = keysHashValue[..<kCCKeySizeAES128]
        let macKey = keysHashValue[kCCKeySizeAES128...]
        
        // At return, the refs to ephemeralPrivateKey and sharedSecret will be dropped and they will be cleared
        return (exportPublicKey, aesKey, macKey)
    }
    
    static func buildSecretData(_ serverPublicKey: Data, _ plaintext: Data) throws -> Data {
        // Get our ephemeral secrets that will de disposed at the end of this function
        let (cachedExportPublicKey, cachedAESKey, cachedMacKey, nonce) = try keyCacheQueue.sync { () -> (Data?, Data?, Data?, Data) in
            if Crypto.keyGenTime <= Int64(Date().timeIntervalSince1970) - KEY_GEN_TIME_DELTA || Crypto.counter >= 65535 {
                (Crypto.cachedExportPublicKey, Crypto.cachedAesKey, Crypto.cachedMacKey) = try getEphemeralSecrets(serverPublicKey)
                Crypto.keyGenTime = Int64(Date().timeIntervalSince1970)
                Crypto.counter = 0
            } else {
                Crypto.counter += 1
            }
            let nonce = withUnsafeBytes(of: Crypto.counter.bigEndian) { Data($0) }
            return (Crypto.cachedExportPublicKey, Crypto.cachedAesKey, Crypto.cachedMacKey, nonce)
        }
        guard let exportPublicKey = cachedExportPublicKey, let aesKey = cachedAESKey, let macKey = cachedMacKey else {
            throw SecurityError.UnexpectedNilKeys
        }

        
        // AES ENCRYPT DATA
        // IV = AES(ctr, iv=null), AES(plaintext, iv=IV) === AES(ctr_with_padding || plaintext, iv=null)
        // Using the latter construction to reduce key expansions
        
        // Under PKCS#7 padding, we pad out to a complete blocksize but if the input is an exact multiple of blocksize,
        // then we add an extra block on. So in both cases it's 16 bytes + (dataLen/16 + 1) * 16 bytes long
        let outputLen = ((plaintext.count / kCCBlockSizeAES128) + 2) * kCCBlockSizeAES128
        
        let nullIV = Data(count: 16)
        var plaintextWithIV = Data(capacity: plaintext.count + 16)
        plaintextWithIV.append(nonce)
        plaintextWithIV.append(NONCE_PADDING)
        plaintextWithIV.append(plaintext)
        
        var ciphertextWithIV = Data(count: outputLen)
        var dataWrittenLen = 0
        let status = ciphertextWithIV.withUnsafeMutableBytes { ciphertextPtr in
            plaintextWithIV.withUnsafeBytes { plaintextPtr in
                nullIV.withUnsafeBytes { ivPtr in
                    aesKey.withUnsafeBytes { aesKeyPtr in
                        return CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                       aesKeyPtr.baseAddress, kCCKeySizeAES128, ivPtr.baseAddress,
                                       plaintextPtr.baseAddress, plaintextWithIV.count,
                                       ciphertextPtr.baseAddress, outputLen,
                                       &dataWrittenLen)
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            throw SecurityError.EncryptionFailedError(status)
        }
        guard outputLen == dataWrittenLen else {
            throw SecurityError.EncryptionLengthError
        }
        
        let ciphertext = ciphertextWithIV[16...]
        
        // HMAC
        var macValue = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        var hmacContext = CCHmacContext()
        macKey.withUnsafeBytes { CCHmacInit(&hmacContext, CCHmacAlgorithm(kCCHmacAlgSHA256), $0.baseAddress, macKey.count) }
        exportPublicKey.withUnsafeBytes { CCHmacUpdate(&hmacContext, $0.baseAddress, exportPublicKey.count) }
        nonce.withUnsafeBytes { CCHmacUpdate(&hmacContext, $0.baseAddress, nonce.count) }
        ciphertext.withUnsafeBytes { CCHmacUpdate(&hmacContext, $0.baseAddress, ciphertext.count) }
        macValue.withUnsafeMutableBytes { CCHmacFinal(&hmacContext, $0.bindMemory(to: UInt8.self).baseAddress) }
        
        // Build the final payload: ephemeral public key || nonce || encrypted data || HMAC
        var finalData = Data(capacity: exportPublicKey.count + ciphertext.count + 18)
        finalData.append(exportPublicKey)
        finalData.append(nonce)
        finalData.append(ciphertext)
        finalData.append(macValue[..<16])
        
        return finalData
    }
    
    public static func encrypt(dataToEncrypt: Data) throws -> String {
        guard let publicKey = publicKey else {
            throw SecurityError.PublicKeyCopyError
        }
        let encryptedData = try buildSecretData(publicKey, dataToEncrypt)
        return encryptedData.base64EncodedString()
    }
}
