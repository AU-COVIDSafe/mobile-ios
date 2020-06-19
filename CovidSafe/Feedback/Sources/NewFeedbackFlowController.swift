//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

class NewFeedbackFlowController: UINavigationController {
  let newFeedbackViewController: FeedbackViewController
  var leftBarButtonItem: UIBarButtonItem!
  var originalStatusBarStyle: UIStatusBarStyle?
  var onDidFinish: (() -> Void)?

  let navBarStyle: NavigationBarStyle
  let shouldUseCustomTransition: Bool

  init(screenshot: UIImage?, settings: FeedbackSettings? = nil) throws {
    newFeedbackViewController = try NewFeedbackFlowViewControllerFactory()
      .createNewFeedbackViewControllerWithScreenshotImage(screenshot, settings: settings)

    navBarStyle = settings?.navigationBarStyle ?? .defaultStyle

    shouldUseCustomTransition = screenshot != nil

    super.init(nibName: nil, bundle: nil)
    newFeedbackViewController.onDidFinish = {
      self.dismissFeedbackFlow()
    }
    viewControllers = [newFeedbackViewController]

    leftBarButtonItem = self.createCancelBarButtonItem()
    newFeedbackViewController.navigationItem.leftBarButtonItem = leftBarButtonItem
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) is not supported by NewFeedbackFlowController")
  }
}

extension NewFeedbackFlowController {
  // MARK: View Lifecycle & UIKit

  override func viewDidLoad() {
    super.viewDidLoad()
    transitioningDelegate = self
    newFeedbackViewController.flowNavBarStyle = UIApplication.shared.statusBarStyle
    navigationBar.style(navigationBarStyle: navBarStyle)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    applyStatusBarStyleIfNeeded()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    returnStatusBarStyleToOriginalValueIfNeeded()
  }

  // Feedback flow considered finished when this view controller's view has disappeared.
    override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.onDidFinish?()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return navBarStyle.statusBarStyle
  }

  func applyStatusBarStyleIfNeeded() {
    if Foundation.Bundle.main.viewControllerBasedStatusBarAppearance == false {
      originalStatusBarStyle = UIApplication.shared.statusBarStyle
      newFeedbackViewController.flowNavBarStyle = navBarStyle.statusBarStyle
    }
  }

  func returnStatusBarStyleToOriginalValueIfNeeded() {
    if Foundation.Bundle.main.viewControllerBasedStatusBarAppearance == false {
      if let originalStatusBarStyle = originalStatusBarStyle {
        newFeedbackViewController.flowNavBarStyle = originalStatusBarStyle
      }
    }
  }
}

extension NewFeedbackFlowController {
  // MARK: User Actions

    @objc func cancel() {
    newFeedbackViewController.cancel()
    dismissFeedbackFlow()
  }

  func presentKeyboard() {
    newFeedbackViewController.presentKeyboard()
  }

  func dismissFeedbackFlow() {
    if let actionController = self.presentingViewController as? UIAlertController {
      if let presentingViewController = actionController.presentingViewController {
        actionController.view.isHidden = true
        presentingViewController.dismiss(animated: false) {
          self.onDidFinish?()
          actionController.view.isHidden = false
          presentingViewController.present(actionController, animated: true, completion: nil)
        }
        return
      }
    }

    presentingViewController?.dismiss(animated: true) {
      self.onDidFinish?()
    }
  }
}

extension NewFeedbackFlowController {
  // MARK: Factories

  func createCancelBarButtonItem() -> UIBarButtonItem {
    let buttonTitle = "global_cancel_button_title".localizedString()

    let item = UIBarButtonItem(
      title: buttonTitle,
      style: .plain,
      target: self,
      action: #selector(NewFeedbackFlowController.cancel)
    )
    
    item.tintColor = .covidSafeColor
    return item
  }
}

extension NewFeedbackFlowController: UIViewControllerTransitioningDelegate {
  // MARK: Custom Transition Presentation

  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return nil
  }
}

private class NewFeedbackFlowViewControllerFactory {
  let flowStoryboard = UIStoryboard(name: "NewFeedbackFlow", bundle: Bundle.main)

  func createNewFeedbackViewControllerWithScreenshotImage(
    _ screenshotImage: UIImage?,
    settings: FeedbackSettings? = nil) throws -> FeedbackViewController {
      let id = "FeedbackViewController"

      // swiftlint:disable:next force_cast
      let vc = flowStoryboard.instantiateViewController(withIdentifier: id) as! FeedbackViewController

      vc.settings = try settings ?? FeedbackSettings()

      return vc
  }
}

extension Foundation.Bundle {
  fileprivate var viewControllerBasedStatusBarAppearance: Bool {
    return (infoDictionary?["UIViewControllerBasedStatusBarAppearance"] as? Bool) ?? true
  }
}
