//
//  ChangePostcodeAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire

class ChangePostcodeAPI: CovidSafeAuthenticatedAPI {
        
    static func changePostcode(newPostcode: String,
                                  completion: @escaping (CovidSafeAPIError?) -> Void) {

        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            return
        }
        
        let params = [
            "postcode": newPostcode,
            ]
        
        guard let authHeaders = try? authenticatedHeaders() else {
            completion(.RequestError)
            return
        }
        
        CovidNetworking.shared.session.request("\(apiHost)/device",
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            headers: authHeaders,
            interceptor: CovidRequestRetrier(retries:3)).validate().responseDecodable(of: DeviceResponse.self) { (response) in
                switch response.result {
                case .success:
                    completion(nil)
                case .failure(_):
                    guard let statusCode = response.response?.statusCode else {
                        completion(.UnknownError)
                        return
                    }
                    if (statusCode >= 400 && statusCode < 500) {
                        completion(.RequestError)
                        return
                    }
                    completion(.ServerError)
                }
        }
    }
}

struct DeviceResponse: Decodable {
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case message
    }
}
