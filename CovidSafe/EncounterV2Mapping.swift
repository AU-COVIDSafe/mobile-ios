//
//  EncounterV2Mapping.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import CoreData

struct MigrationRemoteBlob: Encodable {
    enum CodingKeys: String, CodingKey {
        case msg
        case modelC
        case modelP
        case rssi
        case txPower
    }
    var msg: String?
    var modelC: String?
    var modelP: String?
    var rssi: NSNumber?
    var txPower: NSNumber?
    
    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let msg = msg {
            try container.encode(msg, forKey: .msg)
        }
        
        if let modelC = modelC, modelC != BluetraceConfig.DummyModel{
            try container.encode(modelC, forKey: .modelC)
        }
        if let modelP = modelP, modelP != BluetraceConfig.DummyModel {
            try container.encode(modelP, forKey: .modelP)
        }
        if let rssi = rssi, rssi.intValue != BluetraceConfig.DummyRSSI {
            try container.encode(rssi.doubleValue, forKey: .rssi)
        }
        if let txPower = txPower, txPower.intValue != BluetraceConfig.DummyTxPower {
            try container.encode(txPower.doubleValue, forKey: .txPower)
        }
    }
    
}


class EncounterV2Mapping: NSEntityMigrationPolicy {
    var localEmptyBlob: String = ""
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        try super.begin(mapping, with: manager)
        let emptyLocal = try JSONEncoder().encode(MigrationRemoteBlob())
        localEmptyBlob = try Crypto.encrypt(dataToEncrypt: emptyLocal)
    }
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        
        if (sInstance.entity.name == "Encounter") {
            guard let version = sInstance.primitiveValue(forKey: "v") as? Int64 else {
                return
            }
            let encounterV2 = NSEntityDescription.insertNewObject(forEntityName: "Encounter", into: manager.destinationContext)
            let msg = sInstance.primitiveValue(forKey: "msg") as? String
            let modelC = sInstance.primitiveValue(forKey: "modelC") as? String
            let modelP = sInstance.primitiveValue(forKey: "modelP") as? String
            let rssi = sInstance.primitiveValue(forKey: "rssi") as? NSNumber
            let txPower = sInstance.primitiveValue(forKey: "txPower") as? NSNumber
            let org = sInstance.primitiveValue(forKey: "org") as? String
            let timestamp = sInstance.primitiveValue(forKey: "timestamp") as? Date
            
            
            encounterV2.setPrimitiveValue(org, forKey: "org")
            encounterV2.setPrimitiveValue(BluetraceConfig.ProtocolVersion, forKey: "v")
            encounterV2.setPrimitiveValue(timestamp, forKey: "timestamp")
            do {
                try autoreleasepool {
                    if version == 1 {
                        //convert a regular old v1 entry
                        encounterV2.setPrimitiveValue(localEmptyBlob, forKey: "localBlob")
                        let remoteBlob = MigrationRemoteBlob(msg: msg, modelC: modelC, modelP: modelP, rssi: rssi, txPower: txPower)
                        
                        let blobJson = try JSONEncoder().encode(remoteBlob)
                        let remoteBlobEncrypted = try Crypto.encrypt(dataToEncrypt: blobJson)
                        encounterV2.setPrimitiveValue(remoteBlobEncrypted, forKey: "remoteBlob")
                        manager.associate(sourceInstance: sInstance, withDestinationInstance: encounterV2, for: mapping)
                        
                    } else if version == 2 {
                        //convert an entry that was recieved from an already updated app (the msg will already be encrypted)
                        let localMigrationBlob = MigrationRemoteBlob(msg: nil, modelC: modelC, modelP: modelP, rssi: rssi, txPower: txPower)
                        let jsonLocal = try JSONEncoder().encode(localMigrationBlob)
                        let localBlob = try Crypto.encrypt(dataToEncrypt: jsonLocal)
                        encounterV2.setPrimitiveValue(localBlob, forKey: "localBlob")
                        encounterV2.setPrimitiveValue(msg, forKey: "remoteBlob")
                        manager.associate(sourceInstance: sInstance, withDestinationInstance: encounterV2, for: mapping)
                    }
                }
            } catch {
                throw(error)
            }
            // we're dropping all the debug messages save to the db during the migration as they're unnessecary
        }
    }
}
