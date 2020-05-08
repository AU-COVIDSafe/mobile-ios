//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

open class HTTPPostFeedbackAction: AsyncAction {
  let issue: Issue
  let screenshotImageOrNil: UIImage?
  let target: JMCTarget
  let onComplete: (Outcome<Void>) -> Void
  var issueData: Data!
  var customFieldsData: Data!

  var issueJSONInfo: [String: NSObject] {
    // Any other interesting pieces of data to grab?
    let issueInfo = issue.infoAsDictionary
    let deviceInfo = UIDevice.current.infoAsDictionary
    let languageInfo = NSLocale.infoAsDictionary
    let bundleInfo = Foundation.Bundle.main.infoAsDictionary
    return [issueInfo, deviceInfo, languageInfo, bundleInfo].reduce([:], +)
  }

  var customFieldsDataOrNil: Data? {
    if issue.customFields.isEmpty {
      return nil
    } else {
      return customFieldsData
    }
  }

  var screenshotImageDataOrNil: Data? {
    switch screenshotImageOrNil {
    case .some(let screenshotImage):
      return screenshotImage.jpegData(compressionQuality: 1.0)
    default:
      return nil
    }
  }

  public init(issue: Issue, screenshotImageOrNil: UIImage? = nil, target: JMCTarget, onComplete: @escaping (Outcome<Void>) -> Void) {
    self.issue = issue
    self.screenshotImageOrNil = screenshotImageOrNil
    self.target = target
    self.onComplete = onComplete
    super.init()
  }

  override open func run() {
    // IMPORTANT: Encoding memory threshold is 10 mb by default.
    do {
      issueData = try serializeIssueData()
      customFieldsData = try serializeCustomFieldsData()
    } catch {
      finishedExecutingOperationWithOutcome(.error(error))
      return
    }

    guard let url = URL(string: target.postIssueURLString) else {
        assertionFailure("Cannot create URL from host & path")
        return
    }

    let boundary = UUID().uuidString
    var request = URLRequest(url: url)
    var data = Data()

    data.append(multipartFormData: issueData, withName: "issue", fileName: "issue.json", boundary: boundary, mimeType: "application/json")

    if let customFieldData = customFieldsDataOrNil {
        data.append(multipartFormData: customFieldData, withName: "customfields", fileName: "customfields.json", boundary: boundary, mimeType: "application/json")
    }

    if let screenshotImageData = screenshotImageDataOrNil {
        data.append(multipartFormData: screenshotImageData, withName: "screenshot", fileName: "screenshot.jpg", boundary: boundary, mimeType: "image/jpeg")
    }

    data.appendString("--\(boundary)--\r\n")

    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.setValue("\(data.count)", forHTTPHeaderField:"Content-Length")
    request.setValue("-x-jmc-requestid", forHTTPHeaderField: UIDevice.current.identifierForVendorString)
    request.httpBody = data

    let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
        DispatchQueue.main.async {
            self.onHTTPResponse(response as? HTTPURLResponse)
        }
    }

    dataTask.resume()
  }

  func onHTTPResponse(_ HTTPResponseOrNil: HTTPURLResponse?) {
    guard let HTTPResponse = HTTPResponseOrNil else {
      finishedExecutingOperationWithOutcome(.error(JMCError.nilHTTPResponseError))
      return
    }

    switch  HTTPResponse.statusCode {
    case let statusCode where statusCode.isSuccessHTTPStatuCode:
      finishedExecutingOperationWithOutcome(.success(()))
    default:
      finishedExecutingOperationWithOutcome(.error(JMCError.httpResponseError))
    }
  }

  func serializeIssueData() throws -> Data {
    return try JSONSerialization.data(withJSONObject: issueJSONInfo, options: [])
  }

  func serializeCustomFieldsData() throws -> Data {
    return try JSONSerialization.data(withJSONObject: issue.customFields, options: [])
  }

  func finishedExecutingOperationWithOutcome(_ outcome: Outcome<Void>) {
    finishedExecutingOperation()
    onComplete(outcome)
  }
}

extension JMCTarget {
  var postIssueURLString: String {
    return "https://" + host + "/" + "rest/jconnect/" + "1.0" + "/issue/create?" + "project=" + projectKey + "&apikey=" + apiKey
  }
}

extension Int {
  fileprivate var isSuccessHTTPStatuCode: Bool {
    return 200...299 ~= self
  }
}

// Add function for combining dictionaries.
private func + <K, V>(lhs: [K : V], rhs: [K : V]) -> [K : V] {
  var combined = lhs

  for (k, v) in rhs {
    combined[k] = v
  }

  return combined
}

extension Data {
    mutating func append(multipartFormData data: Data, withName name: String, fileName: String, boundary: String, mimeType: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendString("\r\n")
    }

    mutating func appendString(_ string: String) {
        append(string.data(using: .utf8)!)
    }
}
