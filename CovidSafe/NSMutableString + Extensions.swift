//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

public extension NSMutableAttributedString {
    @discardableResult
    func addLink(enclosedIn marker: String, urlString: String) -> Bool {
        guard !marker.isEmpty else { return false }
        
        let regexString = marker == "*" ? #"\*(.*?)\*"# : "\(marker)(.*?)\(marker)"
        guard let strRange = string.range(of: regexString, options: .regularExpression) else {
            return false
        }
        let convertedRange = NSRange(strRange, in: string)
        
        let matchingString = string[strRange]
        let enclosedString = matchingString.replacingOccurrences(of: marker, with: "")
        let nsBeginRange = NSRange(location: convertedRange.location, length: marker.count)
        let nsEndRange = NSRange(location: convertedRange.upperBound - marker.count, length: marker.count)
        // first replace end, otherwise the range will change
        replaceCharacters(in: nsEndRange, with: "")
        replaceCharacters(in: nsBeginRange, with: "")
        
        let linkRange = NSRange(location: convertedRange.location, length: enclosedString.count)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .link: urlString,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.covidSafeColor
        ]
        
        addAttributes(attributes, range: linkRange)
        
        return true
    }
}
