//
//  MessageAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire
import KeychainSwift

class MessageAPI {
    
    static let keyLastApiUpdate = "keyLastApiUpdate"

    
    static func getMessagesIfNeeded(completion: @escaping (MessageResponse?, Swift.Error?) -> Void) {
        if shouldGetMessages() {
            guard let token = UserDefaults.standard.string(forKey: "deviceTokenForAPN") else {
                return
            }
            // Make API call to get messages
            let messageRequest = MessageRequest(remotePushToken: token)
            getMessages(msgRequest: messageRequest, completion: completion)
        }
    }
    
    private static func shouldGetMessages() -> Bool {
        let lastChecked = UserDefaults.standard.double(forKey: keyLastApiUpdate)
        var shouldGetMessages = true
        
        let calendar = NSCalendar.current
        let currentDate = calendar.startOfDay(for: Date())
        
        if lastChecked > 0 {
            let lastCheckedDate = Date(timeIntervalSince1970: lastChecked)
            let components = calendar.dateComponents([.day], from: lastCheckedDate, to: currentDate)
            
            if let numDays = components.day {
                shouldGetMessages = numDays > 0
            }
        }
        
        return shouldGetMessages
    }
    
    static func getMessages(msgRequest: MessageRequest,
                            completion: @escaping (MessageResponse?, Swift.Error?) -> Void) {
        let keychain = KeychainSwift()
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidCare-config") else {
            return
        }
        
        guard let token = keychain.get("JWT_TOKEN") else {
            completion(nil, nil)
            return
        }
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)"
        ]
        
        var params = [
            "os" : "ios-\(UIDevice.current.systemVersion)"
            ]

        if let buildString = Bundle.main.version {
            params["appversion"] = "\(buildString)"
        }
        if let remoteToken = msgRequest.remotePushToken {
            params["token"] = remoteToken
        }
        CovidNetworking.shared.session.request("\(apiHost)/messages",
            method: .get,
            parameters: params,
            headers: headers
        ).validate().responseDecodable(of: MessageResponse.self) { (response) in
                switch response.result {
                case .success:
                    guard let messageResponse = response.value else { return }
                    
                    // save successful timestamp
                    let calendar = NSCalendar.current
                    let currentDate = calendar.startOfDay(for: Date())
                    UserDefaults.standard.set(currentDate.timeIntervalSince1970, forKey: keyLastApiUpdate)
                    
                    completion(messageResponse, nil)
                case let .failure(error):
                    completion(nil, error)
                }
        }
    }
}

struct MessageRequest {
    var remotePushToken: String?
}

struct MessageResponse: Decodable {
  let message: String
  let forceappupgrade: Bool
  
}
