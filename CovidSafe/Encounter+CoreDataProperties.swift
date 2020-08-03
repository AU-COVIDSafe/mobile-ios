//
//  Encounter+CoreDataProperties.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//
//

import Foundation
import CoreData
import UIKit
import CoreBluetooth

extension Encounter {
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case org
        case v
        case localBlob
        case remoteBlob
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Encounter> {
        return NSFetchRequest<Encounter>(entityName: "Encounter")
    }

    @nonobjc public class func fetchRequestForRecords() -> NSFetchRequest<Encounter> {
        let fetchRequest = NSFetchRequest<Encounter>(entityName: "Encounter")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return fetchRequest
    }
    
    // Fetch encounters older than 21 days from today.
    @nonobjc public class func fetchOldEncounters() -> NSFetchRequest<NSFetchRequestResult>? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Encounter")
        
        // Get the current calendar with local time zone
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        // Get date 21 days ago
        let today = calendar.startOfDay(for: Date())
        guard let dateTo = calendar.date(byAdding: .day, value: -21, to: today) else {
            return nil
        }
        // Set predicate as date older than 21 days ago
        fetchRequest.predicate = NSPredicate(format: "timestamp <= %@", dateTo as NSDate)
        return fetchRequest
    }
    
    // Fetch encounters in the number of days given.
    @nonobjc public class func fetchEncountersInLast(days: Int) -> NSFetchRequest<Encounter>? {
        let fetchRequest = NSFetchRequest<Encounter>(entityName: "Encounter")

        // Get the current calendar with local time zone
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        // Get date x days ago
        let today = calendar.startOfDay(for: Date())
        guard let dateTo = calendar.date(byAdding: .day, value: -days, to: today) else {
            return nil
        }
        // Set predicate as date since x days ago
        fetchRequest.predicate = NSPredicate(format: "timestamp >= %@", dateTo as NSDate)
        return fetchRequest
    }
    
    @NSManaged public var timestamp: Date?
    @NSManaged public var org: String?
    @NSManaged public var v: NSNumber?
    @NSManaged public var localBlob: String?
    @NSManaged public var remoteBlob: String?

    func set(encounterStruct: EncounterRecord, remoteBlob: String, localBlob: String) {
        setValue(encounterStruct.timestamp, forKeyPath: "timestamp")
        setValue(encounterStruct.org, forKeyPath: "org")
        // when we save locally we've already converted v1 messages to encrypted v2 spec, so we save the record as a v2 record
        if (encounterStruct.v == 1) {
            setValue(BluetraceConfig.ProtocolVersion, forKeyPath: "v")
        } else {
            setValue(encounterStruct.v, forKeyPath: "v")
        }
        setValue(remoteBlob, forKey: "remoteBlob")
        setValue(localBlob, forKey: "localBlob")

    }
    
    // MARK: - Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Int(timestamp!.timeIntervalSince1970), forKey: .timestamp)
        try container.encode(localBlob, forKey: .localBlob)
        try container.encode(remoteBlob, forKey: .remoteBlob)
        try container.encode(org, forKey: .org)
        try container.encode(v?.intValue, forKey: .v)
    }
    
}


