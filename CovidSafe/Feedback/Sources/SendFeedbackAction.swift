//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

open class SendFeedbackAction: AsyncAction {
  let issue: Issue
  let screenshotImageOrNil: UIImage?
  let onComplete: (Outcome<Void>) -> Void

  var getTargetAction: GetJMCTargeAction!
  var postFeedbackAction: HTTPPostFeedbackAction!

  public init(issue: Issue, screenshotImageOrNil: UIImage? = nil, onComplete: @escaping (Outcome<Void>) -> Void) {
    self.issue = issue
    self.screenshotImageOrNil = screenshotImageOrNil
    self.onComplete = onComplete

    super.init()
  }

  override open func run() {
    getTargetAction = GetJMCTargeAction { outcome in
      switch outcome {
      case .success(let JMCTarget):
        self.postFeedbackToTarget(JMCTarget)
      case .error(let error):
        self.finishedExecutingOperationWithOutcome(.error(error))
      case .cancelled:
        break
      }
    }
    getTargetAction.start()
  }

  open func postFeedbackToTarget(_ target: JMCTarget) {
    postFeedbackAction = HTTPPostFeedbackAction(issue: issue, screenshotImageOrNil: screenshotImageOrNil, target: target) { outcome in
     self.finishedExecutingOperationWithOutcome(outcome)
    }
    postFeedbackAction.start()
  }

  func finishedExecutingOperationWithOutcome(_ outcome: Outcome<Void>) {
    finishedExecutingOperation()
    onComplete(outcome)
  }
}
