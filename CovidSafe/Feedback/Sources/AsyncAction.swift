//  Copyright © 2015 Australian Government All rights reserved.

import Foundation

open class AsyncAction: Operation {

  fileprivate var _executing = false
  fileprivate var _finished = false

  override fileprivate(set) open var isExecuting: Bool {
    get {
      return _executing
    }
    set {
      willChangeValue(forKey: "isExecuting")
      _executing = newValue
      didChangeValue(forKey: "isExecuting")
    }
  }

  override fileprivate(set) open var isFinished: Bool {
    get {
      return _finished
    }
    set {
      willChangeValue(forKey: "isFinished")
      _finished = newValue
      didChangeValue(forKey: "isFinished")
    }
  }

  override open var completionBlock: (() -> Void)? {
    set {
      super.completionBlock = newValue
    }
    get {
      return {
        super.completionBlock?()
        self.actionCompleted()
      }
    }
  }

  override open var isAsynchronous: Bool {
    return true
  }

  override open func start() {
    if isCancelled {
      isFinished = true
      return
    }

    isExecuting = true
    autoreleasepool {
      self.run()
    }
  }

  func run() {
    preconditionFailure("This abstract method must be overridden.")
  }

  func actionCompleted() {
    //optional
  }

  func finishedExecutingOperation() {
    isExecuting = false
    isFinished = true
  }
}
