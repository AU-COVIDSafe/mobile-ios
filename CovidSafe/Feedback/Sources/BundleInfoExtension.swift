//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

private class JMCBundleHandle: NSObject { }

extension Foundation.Bundle {
  var version: String? {
    return infoDictionary?["CFBundleVersion"] as? String
  }

  var versionShort: String? {
    return infoDictionary?["CFBundleShortVersionString"] as? String
  }

  var name: String? {
    return infoDictionary?["CFBundleName"] as? String
  }

  var displayName: String? {
    return infoDictionary?["CFBundleDisplayName"] as? String
  }

  var identifier: String? {
    return bundleIdentifier
  }

  var infoAsDictionary: [String: NSObject] {

    return [
      "appVersion": (version ??  "") as NSObject,
      "appVersionShort": versionShort as NSObject? ?? "" as NSObject,
      "appName": (name ?? "") as NSObject,
      "appDisplayName": (displayName ?? "") as NSObject,
      "appId": (identifier ?? "") as NSObject
    ]
  }
}
