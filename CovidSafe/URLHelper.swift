//
//  URLHelper.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation

struct URLHelper {
    static func getAustralianNumberURL() -> String {
        return "\(getHelpURL())#verify-mobile-number-pin"
    }
    static func getHelpURL() -> String {
        let localeId = Locale.current.identifier
        let supportedLocales = Bundle.main.localizations
        let matches = supportedLocales.filter { (supportedLocale) -> Bool in
            return localeId.starts(with: supportedLocale)
        }
        guard let localeCode = matches.first, localeCode != "en" else {
            return "https://www.covidsafe.gov.au/help-topics.html"
        }
        
        return "https://www.covidsafe.gov.au/help-topics/\(localeCode.lowercased()).html"
    }
    
}
