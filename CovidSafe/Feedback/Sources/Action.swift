//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

class Action: Operation {
  override func main() {
    if isCancelled {
      return
    }
    autoreleasepool {
      self.run()
    }
  }

  func run() {
    preconditionFailure("This abstract method must be overridden.")
  }
}
