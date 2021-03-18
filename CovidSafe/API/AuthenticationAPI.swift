//
//  AuthenticationAPI.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import Foundation
import Alamofire
import KeychainSwift

class AuthenticationAPI: CovidSafeAuthenticatedAPI {
        
    private static func issueRefreshTokenAPI(completion: @escaping (ChallengeResponse?, CovidSafeAPIError?) -> Void) {
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            return
        }
        
        CovidNetworking.shared.session.request("\(apiHost)/issueInitialRefreshToken",
           method: .post,
           encoding: JSONEncoding.default,
           headers: authenticatedHeaders
        ).validate().responseDecodable(of: ChallengeResponse.self) { (response) in
            switch response.result {
            case .success:
                guard let challengeResponse = response.value else { return }
                completion(challengeResponse, nil)
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
    
    private static func issueJWTTokenAPI(completion: @escaping (ChallengeResponse?, CovidSafeAPIError?) -> Void) {
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            return
        }
        
        let keychain = KeychainSwift()
        
        guard let token = keychain.get("JWT_TOKEN"),
              let refreshToken = keychain.get("REFRESH_TOKEN"),
              let subject = AuthenticationToken(token: token).getSubject() else {
            completion(nil, .TokenExpiredError)
            return
        }
        
        // get params
        let params: [String : Any] = [
            "subject" : subject,
            "refresh" : refreshToken
        ]
        
        CovidNetworking.shared.session.request("\(apiHost)/reissueAuth",
           method: .post,
           parameters: params,
           encoding: JSONEncoding.default
        ).validate().responseDecodable(of: ChallengeResponse.self) { (response) in
            switch response.result {
            case .success:
                guard let challengeResponse = response.value else { return }
                completion(challengeResponse, nil)
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
    
    static func issueTokensAPI(completion: @escaping (ChallengeResponse?, CovidSafeAPIError?) -> Void) {
        let keychain = KeychainSwift()
        
        // block api call only if refresh token exists, if it doesn't it means the app should get it for the first time
        if UserDefaults.standard.bool(forKey: "ReauthenticationNeededKey") && keychain.get("REFRESH_TOKEN") != nil {
            completion(nil, .TokenExpiredError)
            return
        }
        
        // retrieve and update refresh token
        if keychain.get("REFRESH_TOKEN") == nil {
            AuthenticationAPI.issueRefreshTokenAPI { (response, error) in
                
                guard let jwt = response?.token,
                      let refresh =  response?.refreshToken,
                      error == nil else {
                    
                    completion(response, error)
                    return
                }
                DLog("Authentication API: JWT and refresh tokens updated. \(jwt)")
                
                UserDefaults.standard.set(false, forKey: "ReauthenticationNeededKey")
                keychain.set(jwt, forKey: "JWT_TOKEN", withAccess: .accessibleAfterFirstUnlock)
                keychain.set(refresh, forKey: "REFRESH_TOKEN", withAccess: .accessibleAfterFirstUnlock)
                completion(response, nil)
            }
        } else {
            AuthenticationAPI.issueJWTTokenAPI { (response, error) in
                
                guard let jwt = response?.token,
                      let refresh =  response?.refreshToken,
                      error == nil else {
                    
                    // set corrupted
                    UserDefaults.standard.set(true, forKey: "ReauthenticationNeededKey")
                    completion(response, .TokenExpiredError)
                    return
                }
                DLog("Authentication API: JWT and refresh tokens updated. \(jwt)")
                
                UserDefaults.standard.set(false, forKey: "ReauthenticationNeededKey")
                keychain.set(jwt, forKey: "JWT_TOKEN", withAccess: .accessibleAfterFirstUnlock)
                keychain.set(refresh, forKey: "REFRESH_TOKEN", withAccess: .accessibleAfterFirstUnlock)
                
                completion(response, nil)
                
            }
        }
    }
    
    
}

struct AuthenticationToken {
    var token: String
    
    func getSubject() -> String? {
        let sections = token.split(separator: ".")
        
        guard sections.count >= 2 else { return nil }
        
        // we may want to iterate over all 3 substrings
        var sectionOfInterest = String(sections[1])
        
        // add filler characters if not present
        if (sectionOfInterest.count % 4 > 0){
            sectionOfInterest += String(repeating: "=", count: 4 - (sectionOfInterest.count % 4))
        }
        
        if let decodedData = Data(base64Encoded: sectionOfInterest) {
            let dictionary: [String: Any]? = try? JSONSerialization.jsonObject(with: decodedData, options: []) as? [String: Any]
            
            if let subject = dictionary?["sub"] as? String {
                return subject
            }
        }
        
        return nil
    }
    
    func getExpiry() -> Date? {
        let sections = token.split(separator: ".")
        
        guard sections.count >= 2 else { return nil }
        
        // we may want to iterate over all 3 substrings
        var sectionOfInterest = String(sections[1])
        
        // add filler characters if not present
        if (sectionOfInterest.count % 4 > 0){
            sectionOfInterest += String(repeating: "=", count: 4 - (sectionOfInterest.count % 4))
        }
        
        if let decodedData = Data(base64Encoded: sectionOfInterest) {
            let dictionary: [String: Any]? = try? JSONSerialization.jsonObject(with: decodedData, options: []) as? [String: Any]
            
            if let expiry = dictionary?["exp"] as? Double {
                return Date(timeIntervalSince1970: expiry)
            }
        }
        
        return nil
    }
}
