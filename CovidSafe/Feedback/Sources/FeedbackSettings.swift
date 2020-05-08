//  Copyright © 2020 Australian Government All rights reserved.

import CoreGraphics
import Foundation

public var defaultFeedbackSettings: FeedbackSettings?

public struct FeedbackSettings {
  let JIRATarget: JMCTarget
  let issueType: String
  let issueComponents: [String]
  let customFields: [String: AnyObject]
  let reporterAvatarImage: CGImage?
  var reporterUsernameOrEmail: String?
  let getReporterInfoAsynchronously: ((@escaping (String?, URL?) -> Void) -> Void)?
  let navigationBarStyle: NavigationBarStyle

  public init(
    JIRATarget: JMCTarget,
    issueType: String? = nil,
    issueComponents: [String]? = nil,
    customFields: [String: AnyObject]? = nil,
    navigationBarStyle: NavigationBarStyle,
    reporterAvatarImage: CGImage? = nil,
    reporterUsernameOrEmail: String? = nil,
    getReporterInfoAsynchronously: ((@escaping (_ usernameOrEmail: String?, _ avatarImageURL: URL?) -> Void) -> Void)? = nil
  ) {
    let defaultIssueType = JIRAIssueType.support.rawValue
    let defaultIssueComponents = ["iOS"] 
    let defaultCustomFields = [String: AnyObject]()

    self.JIRATarget = JIRATarget
    self.issueType = (issueType ?? defaultFeedbackSettings?.issueType) ?? defaultIssueType
    self.issueComponents = (issueComponents ?? defaultFeedbackSettings?.issueComponents) ?? defaultIssueComponents
    self.customFields = (customFields ?? defaultFeedbackSettings?.customFields) ?? defaultCustomFields
    self.reporterAvatarImage = reporterAvatarImage ?? defaultFeedbackSettings?.reporterAvatarImage
    self.reporterUsernameOrEmail = reporterUsernameOrEmail ?? defaultFeedbackSettings?.reporterUsernameOrEmail
    self.getReporterInfoAsynchronously = getReporterInfoAsynchronously ?? defaultFeedbackSettings?.getReporterInfoAsynchronously
    self.navigationBarStyle = navigationBarStyle
  }

  public init(
    issueType: String? = nil,
    issueComponents: [String]? = nil,
    customFields: [String: AnyObject]? = nil,
    navigationBarStyle: NavigationBarStyle = .defaultStyle,
    reporterAvatarImage: CGImage? = nil,
    reporterUsernameOrEmail: String? = nil,
    getReporterInfoAsynchronously: ((@escaping (_ usernameOrEmail: String?, _ avatarImageURL: URL?) -> Void) -> Void)? = nil
  ) throws {
    let target = try defaultFeedbackSettings?.JIRATarget ?? JMCTarget.createTargetFromJSONOnDisk()
    self.init(
      JIRATarget: target,
      issueType: issueType,
      issueComponents: issueComponents,
      customFields: customFields,
      navigationBarStyle: navigationBarStyle,
      reporterAvatarImage: reporterAvatarImage,
      reporterUsernameOrEmail: reporterUsernameOrEmail,
      getReporterInfoAsynchronously: getReporterInfoAsynchronously
    )
  }
}

public enum JIRAIssueType: String {
    case support = "Support"
    case bug = "Bug"
    case task = "Task"
    case improvement = "Improvement"
    case story = "Story"
    case epic = "Epic"
}
