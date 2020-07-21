//
//  BLELog+CoreDataProperties.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//
//

import Foundation
import CoreData
import UIKit
import CoreBluetooth

extension BLELog {
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case message
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Encounter> {
        return NSFetchRequest<Encounter>(entityName: "BLELog")
    }

    @nonobjc public class func fetchRequestForRecords() -> NSFetchRequest<Encounter> {
        let fetchRequest = NSFetchRequest<Encounter>(entityName: "BLELog")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return fetchRequest
    }
    
    @NSManaged public var timestamp: Date?
    @NSManaged public var message: String?
    
    // MARK: - Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Int(timestamp!.timeIntervalSince1970), forKey: .timestamp)
        try container.encode(message, forKey: .message)
    }
    
}

