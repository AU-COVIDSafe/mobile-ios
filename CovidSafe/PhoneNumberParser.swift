//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

final class PhoneNumberParser {
    
    // e.g. 412 345 678
    static let numberOfDigits = 9
    static let mobilePhoneNumberPrefix = "4"
    
    enum Error: Swift.Error {
        case notDigits
        case incorrectDigitCount
        case incorrectMobilePhoneNumberPrefix
    }
    
    static func parse(_ string: String) -> Result<String, Error> {
        // Remove all spaces
        var string = string.replacingOccurrences(of: " ", with: "")
        
        // Remove leading "+61"
        if string.hasPrefix("+61") {
            string.removeFirst(3)
        }
        
        // Check for digit only
        guard string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
            return .failure(.notDigits)
        }
        
        // Remove leading "0"
        if string.hasPrefix("0") {
            string.removeFirst()
        }
        
        guard string.hasPrefix(mobilePhoneNumberPrefix) else {
            return .failure(.incorrectMobilePhoneNumberPrefix)
        }
        
        // Check number of digits
        guard string.count == Self.numberOfDigits else {
            return .failure(.incorrectDigitCount)
        }
        
        return .success(string)
    }
}
