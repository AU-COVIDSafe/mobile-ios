//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

public extension NSMutableAttributedString {
    
    
    func parseHTMLLinks() {
        while canParseHtmlOccurenceLink() {
            parseHtmlOccurenceLink()
        }
    }
    
    fileprivate func canParseHtmlOccurenceLink() -> Bool {
        let regexLinkStartElementString = #"\<a(.*?)\>"#
        let regexLinkEndElementTextString = #"\<\/a\>"#
        guard string.range(of: regexLinkStartElementString, options: .regularExpression) != nil else {
            return false
        }
        guard string.range(of: regexLinkEndElementTextString, options: .regularExpression) != nil else {
            return false
        }
        
        return true
    }
    
    fileprivate func parseHtmlOccurenceLink() {
        let regexLinkStartElementString = #"\<a(.*?)\>"#
        let regexLinkEndElementTextString = #"\<\/a\>"#
        guard let strStartElementRange = string.range(of: regexLinkStartElementString, options: .regularExpression) else {
            return
        }
        guard let strEndElementRange = string.range(of: regexLinkEndElementTextString, options: .regularExpression) else {
            return
        }
        
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
        
        let convertedStartRange = NSRange(strStartElementRange, in: string)
        let convertedEndRange = NSRange(strEndElementRange, in: string)
        
        let nsStartElementRange = NSRange(location: convertedStartRange.location, length: convertedStartRange.upperBound - convertedStartRange.lowerBound)
        let nsEndElementRange = NSRange(location: convertedEndRange.location, length: convertedEndRange.upperBound - convertedEndRange.lowerBound)
        
        //remove html marking from text
        replaceCharacters(in: nsEndElementRange, with: "*")
        replaceCharacters(in: nsStartElementRange, with: "*")
        addLink(enclosedIn: "*", urlString: urlString)
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
}
