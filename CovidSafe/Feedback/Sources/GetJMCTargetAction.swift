//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

class GetJMCTargeAction: AsyncAction {
  let onComplete: (Outcome<JMCTarget>) -> Void

  init(onComplete: @escaping (Outcome<JMCTarget>) -> Void) {
    self.onComplete = onComplete
    super.init()
  }

  override func run() {
    do {
      let target = try JMCTarget.createTargetFromJSONOnDisk()
      finishedExecutingOperationWithOutcome(.success(target))
    } catch {
      finishedExecutingOperationWithOutcome(.error(error))
    }
  }

  func finishedExecutingOperationWithOutcome(_ outcome: Outcome<JMCTarget>) {
    finishedExecutingOperation()
    onComplete(outcome)
  }
}
