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
        case msg
        case modelC
        case modelP
        case rssi
        case txPower
        case org
        case v
    }
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Encounter> {
        return NSFetchRequest<Encounter>(entityName: "Encounter")
    }
    
    @nonobjc public class func fetchRequestForRecords() -> NSFetchRequest<Encounter> {
        let fetchRequest = NSFetchRequest<Encounter>(entityName: "Encounter")
        let predicateString = Encounter.Event
            .allCases
            .map { "msg != '\($0.rawValue)'" }
            .joined(separator: " and ")
        
        fetchRequest.predicate = NSPredicate(format: predicateString)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return fetchRequest
    }
    
    @nonobjc public class func fetchRequestForEvents() -> NSFetchRequest<Encounter> {
        let fetchRequest = NSFetchRequest<Encounter>(entityName: "Encounter")
        let predicateString = Encounter.Event
            .allCases
            .map { "msg = '\($0.rawValue)'" }
            .joined(separator: " or ")
        
        fetchRequest.predicate = NSPredicate(format: predicateString)
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
    
    @NSManaged public var timestamp: Date?
    @NSManaged public var msg: String?
    @NSManaged public var modelC: String?
    @NSManaged public var modelP: String?
    @NSManaged public var rssi: NSNumber?
    @NSManaged public var txPower: NSNumber?
    @NSManaged public var org: String?
    @NSManaged public var v: NSNumber?

    func set(encounterStruct: EncounterRecord) {
        setValue(encounterStruct.timestamp, forKeyPath: "timestamp")
        setValue(encounterStruct.msg, forKeyPath: "msg")
        setValue(encounterStruct.modelC, forKeyPath: "modelC")
        setValue(encounterStruct.modelP, forKeyPath: "modelP")
        setValue(encounterStruct.rssi, forKeyPath: "rssi")
        setValue(encounterStruct.txPower, forKeyPath: "txPower")
        setValue(encounterStruct.org, forKeyPath: "org")
        setValue(encounterStruct.v, forKeyPath: "v")
    }
    
    // MARK: - Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Int(timestamp!.timeIntervalSince1970), forKey: .timestamp)
        try container.encode(msg, forKey: .msg)
        
        if let modelC = modelC, let modelP = modelP {
            try container.encode(modelC, forKey: .modelC)
            try container.encode(modelP, forKey: .modelP)
            try container.encode(rssi?.doubleValue, forKey: .rssi)
            try container.encode(txPower?.doubleValue, forKey: .txPower)
            try container.encode(org, forKey: .org)
            try container.encode(v?.intValue, forKey: .v)
        }
    }
    
}
