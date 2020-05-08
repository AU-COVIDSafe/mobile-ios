//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

extension NSLocale {
  class var languageDisplayNameOrNil: String? {
    // Consider going to NSBundle preferredLocalizations to get language the user is actually seeing in the running app.
    guard let languageCode = preferredLanguages[safe: 0] else {
      return nil
    }

    return current.localizedString(forLanguageCode: languageCode)
  }

  class var preferredLanguageDisplayName: String? {
    guard let languageDisplayName = languageDisplayNameOrNil else {
      return nil
    }
    return languageDisplayName
  }

  class var infoAsDictionary: [String: NSObject] {
    return ["language": preferredLanguageDisplayName as NSObject? ?? "" as NSObject]
  }
}

extension Array {
  fileprivate subscript (safe index: UInt) -> Element? {
    return Int(index) < count ? self[Int(index)] : nil
  }
}
