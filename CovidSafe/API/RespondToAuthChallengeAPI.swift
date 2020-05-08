//
//  PhoneValidationAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire

class RespondToAuthChallengeAPI {
        
    static func respondToAuthChallenge(session: String,
                                       code: String,
                                       completion: @escaping (String?, ChallengeErrorResponse?) -> Void) {
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            return
        }
        let params = [
            "session": session,
            "code": code
        ]

        CovidNetworking.shared.session.request("\(apiHost)/respondToAuthChallenge", method: .post, parameters: params, encoding: JSONEncoding.default).validate().responseDecodable(of: ChallengeResponse.self) { (response) in
            switch response.result {
            case .success:
                guard let challengeResponse = response.value else { return }
                completion(challengeResponse.token, nil)
            case .failure(_):
                guard let errorData = response.data else {
                    completion(nil, nil)
                    return
                }
                var errorResp: ChallengeErrorResponse
                do {
                    let decoder = JSONDecoder()
                    errorResp = try decoder.decode(ChallengeErrorResponse.self, from: errorData)
                } catch {
                    DLog("error parsing response \(error)")
                    completion(nil, nil)
                    return
                }
                completion(nil, errorResp)
            }
        }
    }
}

struct ChallengeErrorResponse: Decodable, Error {
    let message: String

    enum CodingKeys: String, CodingKey {
        case message
    }
}

struct ChallengeResponse: Decodable {
  let token: String
  
  enum CodingKeys: String, CodingKey {
    case token
  }
}
