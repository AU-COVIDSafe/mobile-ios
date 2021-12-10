//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

extension UITextView {
    func addLink(_ linkString: String, enclosedIn marker: String) {
        guard let attributedText = attributedText else { return }
        
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        mutableString.addLink(enclosedIn: marker, urlString: linkString)
        self.attributedText = mutableString
        tintColor = UIColor.covidSafeColor
    }
    
    func addAllBold(enclosedIn marker: String) {
        guard let attributedText = attributedText else { return }
        
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        while mutableString.canParseOccurence(elementStartRegex: marker, elementEndRegex: marker) {
            mutableString.addBold(enclosedIn: marker)
        }
        self.attributedText = mutableString
    }
    
    func parseHTMLTags() {
        guard let attributedText = attributedText else { return }
        
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        mutableString.parseHTMLLinks()
        mutableString.parseBoldTags()
        mutableString.parseItalicTags()
        self.attributedText = mutableString
        tintColor = UIColor.covidSafeColor
    }
}
