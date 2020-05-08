//
//  CovidRequestInterceptor.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire
final class CovidRequestRetrier: Alamofire.RequestInterceptor {
    private let numRetries: Int
    private var retriesExecuted: Int = 0
    
    init(retries: Int) {
        self.numRetries = retries
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let response = request.task?.response as? HTTPURLResponse, response.statusCode == 403 else {
            /// The request did not fail due to a 403 Forbidden response.
            let isServerTrustEvaluationError = error.asAFError?.isServerTrustEvaluationError ?? false
            if ( retriesExecuted >= numRetries || isServerTrustEvaluationError) {
                return completion(.doNotRetryWithError(error))
            }
            retriesExecuted += 1
            return completion(.retryWithDelay(1.0))
        }
        return completion(.doNotRetryWithError(error))
    }
}
