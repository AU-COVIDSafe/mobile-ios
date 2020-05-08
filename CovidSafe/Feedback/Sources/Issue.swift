//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

let maxSummaryLength = 240
public struct Issue {
  let summary: String
  let description: String
  let components: [String]
  let type: String
  let customFields: [String: AnyObject]

  public init(summary: String, description: String, components: [String], type: String, customFields: [String: AnyObject] = [:], reporterUsernameOrEmail: String? = nil) {
    self.summary = summary
    self.description = description.withReporterUsernameOrEmailAppended(reporterUsernameOrEmail)
    self.components = components
    self.type = type
    self.customFields = customFields
  }

  public init(feedback: String, components: [String], type: String, customFields: [String: AnyObject] = [:], reporterUsernameOrEmail: String? = nil) {
    switch feedback.unicodeScalars.count {
    case let count where count > maxSummaryLength:
      let truncatedSummary = String(feedback.unicodeScalars.prefix(maxSummaryLength))
      self.init(
        summary: truncatedSummary,
        description: feedback,
        components: components,
        type: type,
        customFields: customFields,
        reporterUsernameOrEmail: reporterUsernameOrEmail
      )
    default:
      self.init(
        summary: feedback,
        description: feedback,
        components: components,
        type: type,
        customFields: customFields,
        reporterUsernameOrEmail: reporterUsernameOrEmail
      )
    }
  }
}

extension String {
  fileprivate func withReporterUsernameOrEmailAppended(_ reporterUsernameOrEmail: String?) -> String {
    guard let reporterUsernameOrEmail = reporterUsernameOrEmail else {
        return self
    }

    return "\(self) \n\n Submitted by: \(reporterUsernameOrEmail)"
  }
}
