//
//  PhoneValidationAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire

class PhoneValidationAPI {
        
    static func verifyPhoneNumber(regInfo: RegistrationRequest,
                                  completion: @escaping (String?, Swift.Error?) -> Void) {

        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            return
        }
        
        let params = [
            "country_code": "+\(regInfo.countryPhoneCode ?? "61")",
            "phone_number": regInfo.phoneNumber,
            "age": String(regInfo.age),
            "postcode": regInfo.postcode,
            "name": regInfo.fullName,
            "device_id": UIDevice.current.identifierForVendor!.uuidString
            ]
        CovidNetworking.shared.session.request("\(apiHost)/initiateAuth",
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            interceptor: CovidRequestRetrier(retries:3)).validate().responseDecodable(of: AuthResponse.self) { (response) in
                switch response.result {
                case .success:
                    guard let authResponse = response.value else { return }
                    completion(authResponse.session, nil)
                case let .failure(error):
                    completion(nil, error)
                }
        }
    }
}

struct RegistrationRequest {
    var fullName: String
    var postcode: String
    var age: Int
    var isMinor: Bool
    var phoneNumber: String
    var countryPhoneCode: String?
}

struct AuthResponse: Decodable {
  let session: String
  let challengeName: String
  
  enum CodingKeys: String, CodingKey {
    case session
    case challengeName
  }
}

protocol RegistrationHandler {
    var registrationInfo: RegistrationRequest? { get set }
}
