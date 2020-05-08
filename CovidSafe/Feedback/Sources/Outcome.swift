//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

public typealias VoidOutcome = Outcome<Void>

public enum Outcome<T> {
  case success(T)
  case error(Error)
  case cancelled

  public init(resultOrNil: T?, errorOrNil: Error?) {
    if let error = errorOrNil {
      self = .error(error)
      return
    }
    if let result = resultOrNil {
      self = .success(result)
      return
    }
    self = .error(ProgrammerError.encounteredNilResultAndNilErrorOutcome)
  }

  public init<A>(somethingOrNothing: A?, resultIfSomething: T, errorIfNothing: Error) {
    if somethingOrNothing != nil {
      self = .success(resultIfSomething)
    } else {
      self = .error(errorIfNothing)
    }
  }
}

enum ProgrammerError: Error {
  case encounteredNilResultAndNilErrorOutcome
}
