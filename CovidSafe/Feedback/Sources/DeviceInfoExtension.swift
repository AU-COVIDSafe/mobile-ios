//  Copyright © 2020 Australian Government All rights reserved.


import UIKit

extension UIDevice {
  var infoAsDictionary: [String: NSObject] {
    return ["devName": name as NSObject,
      "systemName": systemName as NSObject,
      "systemVersion": systemVersion as NSObject,
      "model": model as NSObject,
      "uuid": identifierForVendorString as NSObject]
  }
}

extension UIDevice {
  var identifierForVendorString: String {
    return identifierForVendor?.uuidString ?? ""
  }
}
