//
//  SecKey+CovidSafe.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation

extension SecKey {
  enum SecKeyError: Error {
    case UnableToInspectAttributesError
    case UnsupportedKeyTypeError
    case InvalidUncompressedRepresentationError
  }

  /**
   Copy the compressed elliptic-curve public key representation as defined in
   section 4.3.6 of ANSI X9.62.

   - Throws:
     - `SecKeyError.UnableToInspectAttributesError`: if `SecKeyCopyAttributes()` fails on the key
     - `SecKeyError.UnsupportedKeyTypeError`: if the key isn't of type `kSecAttrKeyTypeECSECPrimeRandom`
     - `SecKeyError.InvalidUncompressedRepresentationError`: if parsing the uncompressed representation
       of the key failed (from `SecKeyCopyExternalRepresentation()`)

   - Returns: Data with 1 + key size bytes, representing the public key
   */
  func CopyCompressedECPublicKey() throws -> Data {
    // Validate the key is of EC type
    guard let attributes = SecKeyCopyAttributes(self) as? [CFString: AnyObject] else {
      throw SecKeyError.UnableToInspectAttributesError
    }
    guard attributes[kSecAttrKeyType] as! CFNumber == kSecAttrKeyTypeECSECPrimeRandom else {
      throw SecKeyError.UnsupportedKeyTypeError
    }
    // Get key size in bytes
    let keySize = Int(truncating: attributes[kSecAttrKeySizeInBits] as! CFNumber) / 8

    // Get the uncompressed key representation
    var err: Unmanaged<CFError>?
    guard let uncompressed = SecKeyCopyExternalRepresentation(self, &err) as Data? else {
      throw err!.takeRetainedValue() as Error
    }
    // Uncompressed begins with 0x04 per section 4.3.6 of X9.62
    guard uncompressed[0] == 4 else {
      throw SecKeyError.InvalidUncompressedRepresentationError
    }
    // Uncompressed public key will be 1 + keysize * 2, private has K appended to public
    guard uncompressed.count >= 1 + keySize * 2 else {
      throw SecKeyError.InvalidUncompressedRepresentationError
    }

    // To compress, take the X coordinate
    let x = uncompressed[1...keySize]
    // And determine whether Y coordinate is odd or even
    let y_lsb = uncompressed[keySize*2] & 1

    // Compressed format is PC || X_1
    var compressed = Data(capacity: 1 + keySize)
    // PC: 0x02 if even, 0x03 if odd
    compressed.append(2 | y_lsb)
    compressed.append(x)

    return compressed
  }
}
