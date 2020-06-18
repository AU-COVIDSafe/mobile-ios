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
        return NSLocalizedString(self, comment: comment)
    }
}
