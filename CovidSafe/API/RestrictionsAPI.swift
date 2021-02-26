//
//  RestrictionsAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire

class RestrictionsAPI: CovidSafeAuthenticatedAPI {
        
    static func getRestrictions(forState: StateTerritory, completion: @escaping (StateRestriction?, CovidSafeAPIError?) -> Void) {
        
        guard forState != .AU else {
            completion(nil, .RequestError)
            return
        }
        
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            completion(nil, .RequestError)
            return
        }
        
        guard let headers = try? authenticatedHeaders() else {
            completion(nil, .TokenExpiredError)
            return
        }
        
        let params = ["state": "\(forState.rawValue.lowercased())"]
        
        CovidNetworking.shared.session.request("\(apiHost)/restrictions",
            method: .get,
            parameters: params,
            headers: headers
        ).validate().responseDecodable(of: StateRestriction.self) { (response) in
            switch response.result {
            case .success:
                guard let restrictionsResponse = response.value else { return }

                completion(restrictionsResponse, nil)
            case .failure(_):
                guard let statusCode = response.response?.statusCode else {
                    completion(nil, .UnknownError)
                    return
                }
                if (statusCode == 200) {
                    completion(nil, .ResponseError)
                    return
                }

                if statusCode == 401, let respData = response.data {
                    completion(nil, processUnauthorizedError(respData))
                    return
                }

                if (statusCode >= 400 && statusCode < 500) {
                    completion(nil, .RequestError)
                    return
                }
                completion(nil, .ServerError)
            }
        }
    }
}

struct StateRestriction: Codable {
    
    let state: String?
    let activities: [RestrictionsActivity]?
    
    enum CodingKeys: String, CodingKey {
        case state
        case activities
    }
    
    var stateTerritory: StateTerritory {
        get {
            guard let stateStr = state else {
                return StateTerritory.AU
            }
            return StateTerritory(rawValue: stateStr.uppercased()) ?? StateTerritory.AU
        }
    }
}

struct RestrictionsActivity: Codable {
    let activityTitle: String?
    let dateUpdated: String?
    let mainContent: String?
    let sections: [RestrictionActivitySection]?
    
    enum CodingKeys: String, CodingKey {
        case activityTitle = "activity-title"
        case dateUpdated = "content-date-title"
        case mainContent = "content"
        case sections = "subheadings"
    }
}

struct RestrictionActivitySection: Codable {
    let title: String?
    let content: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case content
    }
}
