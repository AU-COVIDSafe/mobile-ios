//
//  PhoneValidationAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire
import KeychainSwift

class GetTempIdAPI {
    
    private static let apiVersion = 2
    
    static func getTempId(completion: @escaping (String?, Int?, Swift.Error?) -> Void) {
        let keychain = KeychainSwift()
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
           return
       }
       
        guard let token = keychain.get("JWT_TOKEN") else {
            completion(nil, nil, nil)
            return
        }
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)"
        ]
        let params = [
            "version" : apiVersion
        ]
        CovidNetworking.shared.session.request("\(apiHost)/getTempId",
            method: .get,
            parameters: params,
            headers: headers,
            interceptor: CovidRequestRetrier(retries: 3)).validate().responseDecodable(of: TempIdResponse.self) { (response) in
                switch response.result {
                case .success:
                    guard let tempIdResponse = response.value else { return }
                    completion(tempIdResponse.tempId, tempIdResponse.expiryTime, nil)
                case let .failure(error):
                    completion(nil, nil, error)
                }
        }
    }
}

struct TempIdResponse: Decodable {
    let tempId: String
    let expiryTime: Int
    let refreshTime: Int
  
  enum CodingKeys: String, CodingKey {
    case tempId
    case expiryTime
    case refreshTime
  }
}
