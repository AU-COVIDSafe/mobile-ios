//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

// MARK: Localization extensions
extension AlertController {
  static func createAlertSheetController(localizedTitle: String, localizedMessage: String) -> AlertController {
    return AlertController(title: localizedTitle, message: localizedMessage, preferredStyle: .actionSheet)
  }

  static func createAlertController(localizedTitle: String, localizedMessage: String) -> AlertController {
    return AlertController(title: localizedTitle, message: localizedMessage, preferredStyle: .alert)
  }
}

extension UIAlertAction {
    convenience init(localizedTitle: String, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)?) {
        self.init(title: localizedTitle, style: style, handler: handler)
  }
}

// MARK: UIAlertController cancel extension
extension UIAlertController {
  func addCancelAction() {
    let cancelActionTitle = NSLocalizedString("global_cancel_button_title",
      tableName: "Feedback",
      bundle: Bundle.main,
      comment: "Cancel button title"
    )
    let cancelAction = UIAlertAction(title: cancelActionTitle, style: .cancel, handler: nil)
    self.addAction(cancelAction)
  }

  func addDefaultAction(localizedTitle: String, handler: @escaping ((UIAlertAction) -> Void)) {
    let defaultAction = UIAlertAction(localizedTitle: localizedTitle, style: .default, handler: handler)
    self.addAction(defaultAction)
  }
}
