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
    static let keyLastVersionChecked = "keyLastVersionChecked"
    
    static func getMessagesIfNeeded(completion: @escaping (MessageResponse?, MessageAPIError?) -> Void) {
        if shouldGetMessages() {
            getMessages(completion: completion)
        }
    }
    
    static func getMessages(completion: @escaping (MessageResponse?, MessageAPIError?) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "deviceTokenForAPN") else {
            completion(nil, .RequestError)
            return
        }
        //Get relevat encounter data
        guard let persistentContainer =
            EncounterDB.shared.persistentContainer else {
                completion(nil, .RequestError)
                return
        }
        let managedContext = persistentContainer.newBackgroundContext()
        guard let encounterLastWeekRequest = Encounter.fetchEncountersInLast(days: 7) else {
            completion(nil, .RequestError)
            return
        }
        
        do {
            //fetch last week encounters count
            let weekEncounters = try managedContext.count(for: encounterLastWeekRequest)
            let healthcheck = BluetraceManager.shared.isBluetoothOn() && BluetraceManager.shared.isBluetoothAuthorized() ?
                healthCheckParamValue.OK :
                healthCheckParamValue.POSSIBLE_ERROR
            let encounterCheck = weekEncounters > 0 ? healthCheckParamValue.OK : healthCheckParamValue.POSSIBLE_ERROR
            
            // Make API call to get messages
            let messageRequest = MessageRequest(remotePushToken: token, healthcheck: healthcheck, encountershealth: encounterCheck)
            getMessages(msgRequest: messageRequest, completion: completion)
            
        } catch let error as NSError {
            completion(nil, .RequestError)
            DLog("Could not fetch encounter(s) from db. \(error), \(error.userInfo)")
        }
    }
    
    private static func shouldGetMessages() -> Bool {
        let lastChecked = UserDefaults.standard.double(forKey: keyLastApiUpdate)
        let versionChecked = UserDefaults.standard.integer(forKey: keyLastVersionChecked)
        
        var shouldGetMessages = true
        
        let calendar = NSCalendar.current
        let currentDate = calendar.startOfDay(for: Date())
        
        // if the current version is newer than the last version checked, allow messages call
        if let currVersionStr = Bundle.main.version, let currVersion = Int(currVersionStr), currVersion > versionChecked {
            return true
        }
        
        if lastChecked > 0 {
            let lastCheckedDate = Date(timeIntervalSince1970: lastChecked)
            let components = calendar.dateComponents([.hour], from: lastCheckedDate, to: currentDate)
            
            if let numHours = components.hour {
                shouldGetMessages = numHours > 4
            }
        }
        
        return shouldGetMessages
    }
    
    private static func getMessages(msgRequest: MessageRequest,
                                    completion: @escaping (MessageResponse?, MessageAPIError?) -> Void) {
        let keychain = KeychainSwift()
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            completion(nil, .RequestError)
            return
        }
        
        guard let token = keychain.get("JWT_TOKEN") else {
            completion(nil, .RequestError)
            return
        }
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)"
        ]
        
        let preferredLanguages = Locale.preferredLanguages.count > 5 ? Locale.preferredLanguages[0...5].joined(separator: ",") : Locale.preferredLanguages.joined(separator: ",")
        
        var params: [String : Any] = [
            "os" : "ios-\(UIDevice.current.systemVersion)",
            "healthcheck" : msgRequest.healthcheck.rawValue,
            "encountershealth" : msgRequest.encountershealth.rawValue,
            "preferredlanguages": preferredLanguages
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
                let minutesToDefer = Int.random(in: 0..<10)
                let calendar = NSCalendar.current
                let currentDate = Date()
                if let deferredDate = calendar.date(byAdding: .minute, value: minutesToDefer, to: currentDate) {
                    UserDefaults.standard.set(deferredDate.timeIntervalSince1970, forKey: keyLastApiUpdate)
                } else {
                    UserDefaults.standard.set(currentDate.timeIntervalSince1970, forKey: keyLastApiUpdate)
                }
                UserDefaults.standard.set(Bundle.main.version, forKey: keyLastVersionChecked)
                
                completion(messageResponse, nil)
            case .failure(_):
                guard let statusCode = response.response?.statusCode else {
                    completion(nil, .UnknownError)
                    return
                }
                if (statusCode == 200) {
                    completion(nil, .ResponseError)
                }
                if (statusCode >= 400 && statusCode < 500) {
                    completion(nil, .RequestError)
                }
                completion(nil, .ServerError)
            }
        }
    }
}

enum healthCheckParamValue: String {
    case OK = "OK"
    case POSSIBLE_ERROR = "POSSIBLE_ERROR"
    case ERROR = "ERROR"
}

struct MessageRequest {
    var remotePushToken: String?
    var healthcheck: healthCheckParamValue
    var encountershealth: healthCheckParamValue
}

struct MessageResponse: Decodable {
    let messages: [Message]?
    let forceappupgrade: Bool
    
    enum CodingKeys: String, CodingKey {
        case messages
        case forceappupgrade
    }
}

struct Message: Decodable {
    let title: String?
    let body: String?
    let destination: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case body
        case destination
    }
}

enum MessageAPIError: Error {
    case RequestError
    case ResponseError
    case ServerError
    case UnknownError
}
