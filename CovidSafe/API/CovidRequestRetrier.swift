//
//  CovidRequestInterceptor.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire
import KeychainSwift

final class CovidRequestRetrier: Alamofire.RequestInterceptor {
    private let numRetries: Int
    private var retriesExecuted: Int = 0
    private var triedRefresh = false
    
    init(retries: Int) {
        self.numRetries = retries
    }
    
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
        let keychain = KeychainSwift()
        let refreshExists = keychain.get("REFRESH_TOKEN") != nil
        // prevent authenticated api calls if the re-registration flow has been started
        if UserDefaults.standard.bool(forKey: "ReauthenticationNeededKey") &&
            refreshExists {
            completion(.failure(CovidSafeAPIError.TokenExpiredError))
            return
        }
        
        // check headers an update if needed.
        // intercept the first call to the API after app updates to retrieve new tokens
        if !refreshExists &&
            keychain.get("JWT_TOKEN") != nil {
            AuthenticationAPI.issueTokensAPI { (response, error) in
                guard let token = response?.token else {
                    completion(.success(urlRequest))
                    return
                }
                // update the token
                urlRequest.headers.add(name: "Authorization", value: "Bearer \(token)")
                completion(.success(urlRequest))
            }
            return
        }
        
        guard let token = keychain.get("JWT_TOKEN"),
              urlRequest.headers["Authorization"] != nil else {
            completion(.success(urlRequest))
            return
        }
        
        // update the token in case is was updated in a retry
        urlRequest.headers.add(name: "Authorization", value: "Bearer \(token)")
        completion(.success(urlRequest))
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        
        guard retriesExecuted < numRetries else {
            completion(.doNotRetryWithError(error))
            return
        }
        
        if let covidError = error.asAFError?.underlyingError as? CovidSafeAPIError, covidError == .TokenExpiredError {
            retriesExecuted = numRetries
            // for some reason the retry is getting called even after doNotRetryWithError below.
            // set retries to max and the guard above stops it all
            completion(.doNotRetryWithError(error))
            return
        }
        
        guard let response = request.task?.response as? HTTPURLResponse, response.statusCode == 403 || response.statusCode == 401 else {
            /// The request did not fail due to a 403 Forbidden response.
            let isServerTrustEvaluationError = error.asAFError?.isServerTrustEvaluationError ?? false
            if ( retriesExecuted >= numRetries || isServerTrustEvaluationError) {
                return completion(.doNotRetryWithError(error))
            }
            retriesExecuted += 1
            return completion(.retryWithDelay(1.0))
        }
        
        if !triedRefresh &&
            (response.statusCode == 403 || response.statusCode == 401) {
            triedRefresh = true
            retriesExecuted += 1
            AuthenticationAPI.issueTokensAPI { (response, authError) in
                // this will update the tokens automatically
                guard let respError = authError, respError == .TokenExpiredError else {
                    completion(.doNotRetryWithError(error))
                    return
                }
                completion(.retryWithDelay(1.0))
            }
            return
        }
        return completion(.doNotRetryWithError(error))
    }
}
