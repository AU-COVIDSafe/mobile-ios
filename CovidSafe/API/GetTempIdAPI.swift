//
//  PhoneValidationAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire

class GetTempIdAPI: CovidSafeAuthenticatedAPI {
    
    private static let apiVersion = 2
    
    static func getTempId(completion: @escaping (String?, Int?, Swift.Error?, CovidSafeAPIError?) -> Void) {
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
           return
       }
       
        guard let headers = try? authenticatedHeaders() else {
            completion(nil, nil, nil, .TokenExpiredError)
            return
        }
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
                    completion(tempIdResponse.tempId, tempIdResponse.expiryTime, nil, nil)
                case let .failure(error):
                    guard let statusCode = response.response?.statusCode else {
                        completion(nil, nil, error, .UnknownError)
                        return
                    }
                    if statusCode == 401, let respData = response.data {
                        completion(nil, nil, error, processUnauthorizedError(respData))
                        return
                    }
                    completion(nil, nil, error, .ServerError)
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
