//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

final class PhoneNumberParser {
    
    // e.g. 412 345 678
    static let numberOfDigitsAu = 9
    static let minNumberOfDigitsNorfolkIsland = 5
    static let maxNumberOfDigitsNorfolkIsland = 6
    static let mobilePhoneNumberNorfolkIslandPrefix = "3"
    static let mobilePhoneNumberAuPrefix = "4"
    
    enum Error: Swift.Error {
        case notDigits
        case incorrectDigitCount
        case incorrectMobilePhoneNumberPrefix
    }
    
    static func parse(_ string: String, countryCode: String) -> Result<String, Error> {
        // Remove all spaces
        var string = string.replacingOccurrences(of: " ", with: "")
        
        if countryCode == "61" {
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
            
            guard string.hasPrefix(mobilePhoneNumberAuPrefix) else {
                return .failure(.incorrectMobilePhoneNumberPrefix)
            }
            
            // Check number of digits
            guard string.count == Self.numberOfDigitsAu else {
                return .failure(.incorrectDigitCount)
            }
            
            return .success(string)
        }
        
        if countryCode == "672" {
            // Remove leading "+672"
            if string.hasPrefix("+672") {
                string.removeFirst(4)
            }
            
            // Check for digit only
            guard string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil else {
                return .failure(.notDigits)
            }

            // Check number of digits
            guard string.count >= self.minNumberOfDigitsNorfolkIsland && string.count <= self.maxNumberOfDigitsNorfolkIsland  else {
                return .failure(.incorrectDigitCount)
            }
            
            if string.count == self.maxNumberOfDigitsNorfolkIsland && !string.hasPrefix(mobilePhoneNumberNorfolkIslandPrefix) {
                return .failure(.incorrectMobilePhoneNumberPrefix)
            }
            
            return .success(string)
        }
        
        // remove country code if present in the phone number
        if string.hasPrefix("+\(countryCode)") {
            string.removeFirst(countryCode.count+1)
        }
        
        
        return .success(string)
    }
}
