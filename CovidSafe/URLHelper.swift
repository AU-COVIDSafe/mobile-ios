//
//  URLHelper.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation

struct URLHelper {
    
    static let host = "https://www.covidsafe.gov.au"
    
    static func getAustralianNumberURL() -> String {
        return "\(getHelpURL())#verify-mobile-number-pin"
    }
    
    private static func getLocale() -> String {
        guard let langCode = Locale.current.languageCode else {
            return "en"
        }
        let localeId = Locale.current.identifier
        let supportedLocales = Bundle.main.localizations
        let matches = supportedLocales.filter { (supportedLocale) -> Bool in
            return localeId.starts(with: supportedLocale)
                || supportedLocale.starts(with: "\(langCode)-") // for punjabi is particularly special that the identifier is pa_AU although
                                                                // the language code in the supported locals is pa-IN.
                                                                // just checking it has the pa- should be enough. I anticipate this happening in other dialects as they come.
        }
        guard let localeCode = matches.first else {
            return "en"
        }
        return localeCode
    }
    
    static func getHelpURL() -> String {
        let localeCode = getLocale()
        guard localeCode != "en" else {
            return "\(host)/help-topics.html"
        }
        
        return "\(host)/help-topics/\(localeCode.lowercased()).html"
    }
    
    static func getPrivacyPolicyURL() -> String {
        return "\(host)/privacy-policy.html"
    }
    
}
