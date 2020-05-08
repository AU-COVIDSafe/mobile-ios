//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

class AlertController: UIAlertController {
  var lastPresentingViewController: UIViewController?
  var useCustomTransition: Bool = true
  var feedbackSettings: FeedbackSettings?

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let viewController = presentingViewController {
      lastPresentingViewController = viewController
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.tintColor = ADGTintColor
  }
}
