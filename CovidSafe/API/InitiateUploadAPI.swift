//
//  InitiateUploadAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire

class InitiateUploadAPI {
    
    static func requestUploadOTP(session: String, completion: @escaping (Bool, APIError?) -> Void) {
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            return
        }
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(session)"
        ]
        CovidNetworking.shared.session.request("\(apiHost)/requestUploadOtp",
           method: .get,
           headers: headers,
           interceptor: CovidRequestRetrier(retries: 3)
        ).validate().responseString { (response) in
            switch response.result {
            case .success:
                if response.value != nil {
                    completion(true, nil)
                } else {
                    completion(false, .ServerError)
                }
            case .failure(_):
                if (response.response?.statusCode == 403) {
                    completion(false, .ExpireSession)
                } else {
                    completion(false, .ServerError)
                }
            }
        }
    }
    
    static func initiateUploadAPI(session: String, pin: String?, completion: @escaping (UploadResponse?, APIError?, String?) -> Void) {
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            return
        }
        var headers: HTTPHeaders = [
            "Authorization": "Bearer \(session)"
        ]
        
        if let uploadPin = pin {
            headers.add(name: "pin", value: uploadPin)
        }
        
        guard pin != nil else {
            completion(nil, .ServerError, nil)
            return
        }
        
        CovidNetworking.shared.session.request("\(apiHost)/initiateDataUpload", method: .get, headers: headers, interceptor: CovidRequestRetrier(retries: 3)).validate().responseData { (response) in
            guard let respData = response.data else {
                completion(nil, .ServerError, "[100] API")
                return
            }
            
            switch response.result {
            case .success:
                do {
                    let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: respData)
                    completion(uploadResponse, nil, nil)
                } catch {
                    completion(nil, .ServerError, "[101] API")
                }
            case .failure(_):
                do {
                    let uploadResponse = try JSONDecoder().decode(ErrorResponse.self, from: respData)
                    completion(nil, .ServerError, "[\(response.response?.statusCode ?? 000)] \(uploadResponse.message)")
                } catch {
                    completion(nil, .ServerError, "[\(response.response?.statusCode ?? 000)] API")
                }
            }
        }
    }
}

struct ErrorResponse: Decodable {
    let message: String
}

struct UploadResponse: Decodable {
    let UploadLink: String
    let UploadPrefix: String
    let ExpiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case UploadLink
        case UploadPrefix
        case ExpiresIn
    }
}
