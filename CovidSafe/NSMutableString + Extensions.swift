//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

public extension NSMutableAttributedString {
    
    enum ElementType {
        case Link,
        Bold
    }
    
    func parseHTMLLinks() {
        let regexLinkStartElementString = #"\<a(.*?)\>"#
        let regexLinkEndElementTextString = #"\<\/a\>"#
        while canParseOccurence(elementStartRegex: regexLinkStartElementString, elementEndRegex: regexLinkEndElementTextString) {
            parseHtmlOccurence(elementStartRegex: regexLinkStartElementString, elementEndRegex: regexLinkEndElementTextString, elementType: .Link)
        }
    }
    
    func parseBoldTags() {
        let regexBoldStartElementString = #"\<b(.*?)\>"#
        let regexBoldEndElementTextString = #"\<\/b\>"#
        while canParseOccurence(elementStartRegex: regexBoldStartElementString, elementEndRegex: regexBoldEndElementTextString) {
            parseHtmlOccurence(elementStartRegex: regexBoldStartElementString, elementEndRegex: regexBoldEndElementTextString, elementType: .Bold)
        }
    }
    
    func canParseOccurence(elementStartRegex: String, elementEndRegex: String) -> Bool {
        guard string.range(of: elementStartRegex, options: .regularExpression) != nil else {
            return false
        }
        guard string.range(of: elementEndRegex, options: .regularExpression) != nil else {
            return false
        }
        
        return true
    }
    
    fileprivate func parseHtmlOccurence(elementStartRegex: String, elementEndRegex: String, elementType: ElementType) {
        guard let strStartElementRange = string.range(of: elementStartRegex, options: .regularExpression) else {
            return
        }
        guard let strEndElementRange = string.range(of: elementEndRegex, options: .regularExpression) else {
            return
        }
        
        let convertedStartRange = NSRange(strStartElementRange, in: string)
        let convertedEndRange = NSRange(strEndElementRange, in: string)
        
        let nsStartElementRange = NSRange(location: convertedStartRange.location, length: convertedStartRange.upperBound - convertedStartRange.lowerBound)
        let nsEndElementRange = NSRange(location: convertedEndRange.location, length: convertedEndRange.upperBound - convertedEndRange.lowerBound)
        
        switch elementType {
        case .Link:
            //get the url string
            var urlString = ""
            let startElementStr = String(string[strStartElementRange])
            if let urlRange = startElementStr.range(of: #"\"(.*?)\""#, options: .regularExpression) {
                let urlMatch = startElementStr[urlRange]
                urlString = String(urlMatch)
                let start = urlString.index(after: urlString.startIndex)
                //ofset by 2 to as the quotes are escaped with \
                let end = urlString.index(urlString.endIndex, offsetBy: -2)
                urlString = String(urlString[start...end])
            }
            //remove html marking from text
            replaceCharacters(in: nsEndElementRange, with: "*")
            replaceCharacters(in: nsStartElementRange, with: "*")
            addLink(enclosedIn: "*", urlString: urlString)
        case .Bold:
            //remove bold marking from text
            replaceCharacters(in: nsEndElementRange, with: "#")
            replaceCharacters(in: nsStartElementRange, with: "#")
            addBold(enclosedIn: "#")
        }
        
    }
    
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
    
    @discardableResult
    func addBold(enclosedIn marker: String) -> Bool {
        guard !marker.isEmpty else { return false }
        
        let regexString = "\(marker)(.*?)\(marker)"
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
        
        // for now only supporting body. Need to get the UIFont from the current string.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(for: .body, weight: .semibold)
        ]
        
        addAttributes(attributes, range: linkRange)
        
        return true
    }
}
