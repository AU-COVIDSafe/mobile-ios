//
//  StateTerritory.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//


enum StateTerritory: String {
    case AU, ACT, NSW, NT, QLD, SA, TAS, VIC, WA
}

extension StateTerritory {
    
    func stateTerritoryFullName() -> String {
        switch self {
        case .ACT:
            return "australian_capital_territory".localizedString()
        case .NSW:
            return "new_south_wales".localizedString()
        case .NT:
            return "northern_territory".localizedString()
        case .QLD:
            return "queensland".localizedString()
        case .SA:
            return "south_australia".localizedString()
        case .TAS:
            return "tasmania".localizedString()
        case .VIC:
            return "victoria".localizedString()
        case .WA:
            return "western_australia".localizedString()
        default:
            return "country_region_name_au".localizedString()

        }
    }
}

extension StateTerritory: SimpleCellObject {
    
    func getCellTitle() -> String {
        return stateTerritoryFullName()
    }
}
