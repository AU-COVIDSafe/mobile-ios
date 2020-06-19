//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

class ViewControllerFactory {

  func createPropmtController(_ useCustomTransition: Bool, settings: FeedbackSettings? = nil) -> UIViewController {
    let title = "entryPrompt_alert_title".localizedString(
        comment: "Title for initial alert when feedback is launched"
    )

    let message = "entryPrompt_alert_message".localizedString(
        comment: "Prompt message for initial alert when feedback is launched"
    )

    let alertController: AlertController
    if UIScreen.main.traitCollection.horizontalSizeClass == .regular {
        alertController = AlertController.createAlertController(localizedTitle: title, localizedMessage: message)
    } else {
        alertController = AlertController.createAlertSheetController(localizedTitle: title, localizedMessage: message)
    }
    alertController.feedbackSettings = settings
    alertController.addNewFeedbackFlowAction()
    alertController.addCancelAction()
    alertController.useCustomTransition = useCustomTransition

    return alertController
  }

  func createNewFeedbackFlowControllerForScreenshotView(
    _ viewForScreenshot: UIView,
    settings: FeedbackSettings? = nil,
    onFlowDidFinish: (() -> Void)? = nil,
    onComplete: @escaping (NewFeedbackFlowController) -> Void
  ) {
    // No-op
  }

  func createNewFeedbackFlowController(
    _ settings: FeedbackSettings? = nil,
    onFlowDidFinish: (() -> Void)? = nil,
    onComplete: (NewFeedbackFlowController) -> Void
  ) {
    do {
      let flowController = try NewFeedbackFlowController(screenshot: nil, settings: settings)
      flowController.onDidFinish = onFlowDidFinish
      onComplete(flowController)
    } catch {
      assertionFailure("\(error)".formattedLoggingStatement)
      onFlowDidFinish?()
    }
  }
}
