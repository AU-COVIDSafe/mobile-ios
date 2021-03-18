//
//  CovidNetworking.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire
import KeychainSwift

final class CovidServerTrustManager: ServerTrustManager {
    override func serverTrustEvaluator(forHost host: String) throws -> ServerTrustEvaluating? {
        guard let evaluator = evaluators[host] else {
            for key in evaluators.keys {
                if (host.hasSuffix(key)) {
                    return evaluators[key]
                }
            }
            if allHostsMustBeEvaluated {
                throw AFError.serverTrustEvaluationFailed(reason: .noRequiredEvaluator(host: host))
            }

            return nil
        }
        return evaluator
    }
}

class CovidNetworking {
    static private let validCerts = [CovidCertificates.AmazonRootCA1, CovidCertificates.AmazonRootCA2, CovidCertificates.AmazonRootCA3, CovidCertificates.AmazonRootCA4, CovidCertificates.SFSRootCA]
    private let evaluators = [
        "covidsafe.gov.au": PinnedCertificatesTrustEvaluator(certificates: CovidNetworking.validCerts)
    ]
    
    static let shared = CovidNetworking()
    public let session: Session
    
    init() {       
        let serverTrustPolicy = CovidServerTrustManager(evaluators: evaluators)
        session = Session(serverTrustManager:serverTrustPolicy)
    }
}

enum APIError: Error {
    case ExpireSession
    case ServerError
}

struct CovidSafeErrorResponse: Decodable {
    let message: String?
}

enum CovidSafeAPIError: Error {
    case RequestError
    case ResponseError
    case ServerError
    case TokenExpiredError
    case UnknownError
}

class CovidSafeAuthenticatedAPI {
    
    static var isBusy = false
    
    static var authenticatedHeaders: HTTPHeaders {
        get {
            let keychain = KeychainSwift()
            
            guard let token = keychain.get("JWT_TOKEN") else {
                return []
            }
            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(token)"
            ]
            return headers
        }
    }
    
    static func processUnauthorizedError(_ data: Data) -> CovidSafeAPIError {
        var errorType = CovidSafeAPIError.RequestError
        do {
            let errorResponse = try JSONDecoder().decode(CovidSafeErrorResponse.self, from: data)
            if errorResponse.message == "Unauthorized" {
                errorType = .TokenExpiredError
            }
        } catch {
            // unable to parse response
            errorType = .ResponseError
        }
        return errorType
    }
}
