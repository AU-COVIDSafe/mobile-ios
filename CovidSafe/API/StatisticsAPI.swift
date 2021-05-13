//
//  MessageAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire

class StatisticsAPI: CovidSafeAuthenticatedAPI {
    
    static let keyCovidStatistics = "keyCovidStatistics"
    
    static func getStatistics(forState: StateTerritory = StateTerritory.AU, completion: @escaping (StatisticsResponse?, CovidSafeAPIError?) -> Void) {
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            completion(nil, .RequestError)
            return
        }
        
        let parameters = ["state" : "\(forState.rawValue)"]
        
        guard let authHeaders = try? authenticatedHeaders() else {
            completion(nil, .RequestError)
            return
        }
        
        CovidNetworking.shared.session.request("\(apiHost)/v2/statistics",
            method: .get,
            parameters: parameters,
            headers: authHeaders,
            interceptor: CovidRequestRetrier(retries: 3)
        ).validate().responseDecodable(of: StatisticsResponse.self) { (response) in
            switch response.result {
            case .success:
                guard let statisticsResponse = response.value else { return }
                let statsData = try? PropertyListEncoder().encode(statisticsResponse)
                UserDefaults.standard.set(statsData, forKey: keyCovidStatistics)
                
                completion(statisticsResponse, nil)
            case .failure(_):
                var lastStats: StatisticsResponse? = nil
                if let savedStats = UserDefaults.standard.data(forKey: keyCovidStatistics) {
                    lastStats = try? PropertyListDecoder().decode(StatisticsResponse.self, from: savedStats)
                }
                guard let statusCode = response.response?.statusCode else {
                    completion(lastStats, .UnknownError)
                    return
                }
                if (statusCode == 200) {
                    completion(lastStats, .ResponseError)
                    return
                }
                
                if statusCode == 401, let respData = response.data {
                    completion(nil, processUnauthorizedError(respData))
                    return
                }
                
                if (statusCode >= 400 && statusCode < 500) {
                    completion(lastStats, .RequestError)
                    return
                }
                completion(lastStats, .ServerError)
            }
        }
    }
}

struct StatisticsResponse: Codable {
    
    let updatedDate: String?
    let responseVersion: String?
    
    let national: StateTerritoryStatistics?
    let act: StateTerritoryStatistics?
    let nsw: StateTerritoryStatistics?
    let nt: StateTerritoryStatistics?
    let qld: StateTerritoryStatistics?
    let sa: StateTerritoryStatistics?
    let tas: StateTerritoryStatistics?
    let vic: StateTerritoryStatistics?
    let wa: StateTerritoryStatistics?
    
    enum CodingKeys: String, CodingKey {
        case updatedDate = "updated_date"
        case national
        case act
        case nsw
        case nt
        case qld
        case sa
        case tas
        case vic
        case wa
        case responseVersion = "version"
    }
    
    func version() -> Int {
        guard let versionStr = responseVersion else {
            return 0
        }
        return Int(versionStr) ?? 0
    }
}

struct StateTerritoryStatistics: Codable {
    let totalCases: Int?
    let activeCases: Int?
    let newCases: Int?
    let recoveredCases: Int?
    let deaths: Int?
    let newLocallyAcquired: Int?
    let locallyAcquired: Int?
    let newOverseasAcquired: Int?
    let overseasAcquired: Int?
    let historicalCases: [HistoricalCase]?
    
    enum CodingKeys: String, CodingKey {
        case totalCases = "total_cases"
        case activeCases = "active_cases"
        case newCases = "new_cases"
        case recoveredCases = "recovered_cases"
        case newLocallyAcquired = "new_locally_acquired"
        case locallyAcquired = "locally_acquired"
        case newOverseasAcquired = "new_overseas_acquired"
        case overseasAcquired = "overseas_acquired"
        case historicalCases = "historical_cases"
        case deaths
    }
}

struct HistoricalCase: Codable {
    let date: String
    let newCases: Int
    
    enum CodingKeys: String, CodingKey {
        case date
        case newCases = "new_cases"
    }
}
