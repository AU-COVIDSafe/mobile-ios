//  Copyright © 2020 Australian Government All rights reserved.

import Foundation

extension JMCTarget {
  static let JSONFileName = "JMCTarget"

  public static func createTargetFromJSONOnDisk() throws -> JMCTarget {
    guard let JMCTargetJSONPath = Foundation.Bundle.main.path(forResource: JSONFileName, ofType: "json") else {
      throw JMCTargetJSONOnDiskError.jsonFileMissingFromBundleError
    }
    return try JMCTarget(JSONFilePath: JMCTargetJSONPath)
  }

  init(JSONFilePath: String) throws {
    guard let JMCTargetData = try? Data(contentsOf: URL(fileURLWithPath: JSONFilePath)) else {
      throw JMCTargetJSONOnDiskError.readJSONFileError
    }
    try self.init(JSONData: JMCTargetData)
  }

  init(JSONData: Data) throws {
    let JSONObject = try JSONSerialization.jsonObject(with: JSONData, options: [])
    guard let JMCTargetDictionary = JSONObject  as? [String : NSObject] else {
      throw JMCTargetJSONOnDiskError.jsonDictionaryToInstanceError
    }
    try self.init(JSONDictionary: JMCTargetDictionary )
  }

  init(JSONDictionary: [String: NSObject]) throws {
    guard let host = JSONDictionary["host"] as? String,
      let apiKey = JSONDictionary["apiKey"] as? String,
      let projectKey = JSONDictionary["projectKey"] as? String else {
        throw JMCTargetJSONOnDiskError.jsonDictionaryToInstanceError
    }
    self.init(host: host, apiKey: apiKey, projectKey: projectKey)
  }

}

public enum JMCTargetJSONOnDiskError: Error {
  case jsonFileMissingFromBundleError
  case readJSONFileError
  case jsonDictionaryToInstanceError
}
