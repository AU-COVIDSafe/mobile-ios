//
//  String+Localization.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//
import Foundation

extension String {
    
    func localizedString( comment: String = "") -> String {
        if self == "" {
            return ""
        }
        
        var localizedString = NSLocalizedString(self, comment: comment)
        
        if localizedString == self {
            // No localized string exists.  Retrieve the display string
            // from the base strings file.
            var bundleForString: Bundle
            if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                let bundle = Bundle(path: path) {
                bundleForString = bundle
            } else {
                bundleForString = Bundle.main
            }

            localizedString = bundleForString.localizedString(forKey: self, value: self, table: nil)
        }
        
        return localizedString
    }
}
