//
//  CovidNetworking.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire

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
