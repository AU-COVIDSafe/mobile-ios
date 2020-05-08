//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

public struct JMCTarget {
  let host: String
  let apiKey: String
  let projectKey: String

  public init(host: String, apiKey: String, projectKey: String) {
    self.host = host
    self.apiKey = apiKey
    self.projectKey = projectKey
  }
}
