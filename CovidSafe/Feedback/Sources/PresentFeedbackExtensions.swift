//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

private var feedbackNotOnScreen = true

extension UIWindow {
  public func presentFeedback(_ promptUser: Bool = false, settings: FeedbackSettings? = nil) {
    guard let presentedViewController = rootViewController?.topmostPresentedViewController else {
      print("\(self), Cannot present feedback prompt because window does not have a presented view controller.".formattedLoggingStatement)
      return
    }

    guard feedbackNotOnScreen else {
      return
    }

    presentedViewController.presentFeedback( promptUser, settings: settings)
  }
}

extension UIViewController {
  func presentFeedbackWithPromptAndScreenshotTransition(_ settings: FeedbackSettings? = nil) {
    guard feedbackNotOnScreen else {
      return
    }

    let vc = ViewControllerFactory().createPropmtController(true, settings: settings)
    self.topmostPresentedViewController.present(vc, animated: true, completion: nil)
  }

  func presentNewFeedbackFlowWithScreenshotTransition(_ settings: FeedbackSettings? = nil) {
    guard let window = view.window else {
      return
    }

    guard feedbackNotOnScreen else {
      return
    }

    feedbackNotOnScreen = false
    ViewControllerFactory().createNewFeedbackFlowControllerForScreenshotView(window, settings: settings, onFlowDidFinish: { [weak self] in
      self?.flowDidFinish()
    }) { flowController in
      self.topmostPresentedViewController.present(flowController, animated: true) {
        if !flowController.shouldUseCustomTransition {
          flowController.presentKeyboard()
        }
      }
    }
  }

  @objc // This method should only be used from ObjC
  public func presentFeedback(
    _ promptUser: Bool = false,
    issueType: String? = nil,
    issueComponents: [String]? = nil,
    reporterAvatarImage: CGImage? = nil,
    reporterUsernameOrEmail: String? = nil
  ) {
    guard let settings = try? FeedbackSettings(
        issueType: issueType,
        issueComponents: issueComponents,
        reporterAvatarImage:
        reporterAvatarImage,
        reporterUsernameOrEmail:
        reporterUsernameOrEmail
      ) else {
        return
    }

    guard feedbackNotOnScreen else {
      return
    }

    presentFeedback( promptUser, settings: settings)
  }

  public func presentFeedback(_ promptUser: Bool = false, settings: FeedbackSettings? = nil) {
    guard feedbackNotOnScreen else {
      return
    }

    if promptUser {
      let vc = ViewControllerFactory().createPropmtController(false, settings: settings)
      self.topmostPresentedViewController.present(vc, animated: true, completion: nil)
    } else {
      self.presentNewFeedbackFlow(settings)
    }
  }

  func presentNewFeedbackFlow(_ settings: FeedbackSettings? = nil) {
    guard feedbackNotOnScreen else {
      return
    }

    feedbackNotOnScreen = false
    ViewControllerFactory().createNewFeedbackFlowController(settings, onFlowDidFinish: { [weak self] in
      self?.flowDidFinish()
    }) { flowController in
      self.topmostPresentedViewController.present(flowController, animated: true) {
        flowController.presentKeyboard()
      }
    }
  }

  private func flowDidFinish() {
    guard Thread.isMainThread else {
      DispatchQueue.main.async(execute: flowDidFinish)
      return
    }

    feedbackNotOnScreen = true
  }
}

extension AlertController {
  func addNewFeedbackFlowAction() {
    let title = "entryPrompt_newFeedback_button_title".localizedString(
        comment: "Button title for button that launches new feedback flow"
    )
    self.addDefaultAction(localizedTitle: title) { [weak self] _ in
      if let strongSelf = self {
        if strongSelf.useCustomTransition {
          strongSelf.presentNewFeedbackFlowWithScreenshotTransition_1()
        } else {
          strongSelf.presentNewFeedbackFlow_1()
        }
      }
    }
  }

  func presentNewFeedbackFlowWithScreenshotTransition_1() {
    guard let presentingViewController = self.lastPresentingViewController else {
      return
    }

    presentingViewController.presentNewFeedbackFlowWithScreenshotTransition(self.feedbackSettings)
  }

  func presentNewFeedbackFlow_1() {
    guard let presentingViewController = self.lastPresentingViewController else {
      return
    }

    presentingViewController.presentNewFeedbackFlow(self.feedbackSettings)
  }
}
