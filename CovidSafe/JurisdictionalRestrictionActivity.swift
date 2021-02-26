//
//  JurisdictionalRestrictionActivity.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import Foundation

public typealias JurisdictionalRestrictionActivity = String

extension JurisdictionalRestrictionActivity: SimpleCellObject {
    
    func getCellTitle() -> String {
        return self
    }
}
