//
//  MessageAPI.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation
import Alamofire
import KeychainSwift

class StatisticsAPI {
    
    static let keyCovidStatistics = "keyCovidStatistics"
    
    static func getStatistics(completion: @escaping (StatisticsResponse?, MessageAPIError?) -> Void) {
        let keychain = KeychainSwift()
        guard let apiHost = PlistHelper.getvalueFromInfoPlist(withKey: "API_Host", plistName: "CovidSafe-config") else {
            completion(nil, .RequestError)
            return
        }
        
        guard let token = keychain.get("JWT_TOKEN") else {
            completion(nil, .RequestError)
            return
        }
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)"
        ]
        
        CovidNetworking.shared.session.request("\(apiHost)/statistics",
            method: .get,
            headers: headers
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
                }
                if (statusCode >= 400 && statusCode < 500) {
                    completion(lastStats, .RequestError)
                }
                completion(lastStats, .ServerError)
            }
        }
    }
}

struct StatisticsResponse: Codable {
    
    let updatedDate: String?
    
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
    }
}

struct StateTerritoryStatistics: Codable {
    let totalCases: Int?
    let activeCases: Int?
    let newCases: Int?
    let recoveredCases: Int?
    let deaths: Int?
    
    enum CodingKeys: String, CodingKey {
        case totalCases = "total_cases"
        case activeCases = "active_cases"
        case newCases = "new_cases"
        case recoveredCases = "recovered_cases"
        case deaths
    }
}
