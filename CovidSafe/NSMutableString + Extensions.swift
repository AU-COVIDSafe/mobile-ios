//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

public extension NSMutableAttributedString {
    @discardableResult
    func addLink(enclosedIn marker: String, urlString: String) -> Bool {
        guard !marker.isEmpty else { return false }
        
        // Begin marker
        guard let beginRange = string.range(of: marker) else { return false }
        let beginLowerBound = string.distance(from: string.startIndex, to: beginRange.lowerBound)
        let beginUpperBound = string.distance(from: string.startIndex, to: beginRange.upperBound)
        let nsBeginRange = NSRange(location: beginLowerBound, length: beginUpperBound - beginLowerBound)
        replaceCharacters(in: nsBeginRange, with: "")
        
        // End marker
        guard let endRange = string.range(of: marker) else { return false }
        let endLowerBound = string.distance(from: string.startIndex, to: endRange.lowerBound)
        let endUpperBound = string.distance(from: string.startIndex, to: endRange.upperBound)
        let nsEndRange = NSRange(location: endLowerBound, length: endUpperBound - endLowerBound)
        replaceCharacters(in: nsEndRange, with: "")
        
        let linkRange = NSRange(location: nsBeginRange.location, length: nsEndRange.location - nsBeginRange.location)
        let attributes: [NSAttributedString.Key: Any] = [
            .link: urlString,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: UIColor.covidSafeColor
        ]
        
        addAttributes(attributes, range: linkRange)
        
        return true
    }
}
