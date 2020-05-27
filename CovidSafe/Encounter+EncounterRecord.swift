//
//  Encounter+EncounterRecord.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreData

extension EncounterRecord {
    
    func saveRemoteCentralToCoreData() throws {
        // remote blob will be modelC rssi txPower msg if v1. If v2 then remoteBlob will just be msg
        // localblob will be modelP
        var localBlob = EncounterBlob()
        localBlob.modelP = self.modelP
        var remoteBlob = EncounterBlob()
        remoteBlob.modelC = self.modelC
        remoteBlob.rssi = self.rssi
        remoteBlob.txPower = self.txPower
        remoteBlob.msg = self.msg
        
        var encryptedLocalBlob: String
        var encryptedRemoteBlob: String
        let localJson = try JSONEncoder().encode(localBlob)
        encryptedLocalBlob = try Crypto.encrypt(dataToEncrypt: localJson)
        if v == 1 {
            let remoteJson = try JSONEncoder().encode(remoteBlob)
            encryptedRemoteBlob = try Crypto.encrypt(dataToEncrypt: remoteJson)
        } else {
            encryptedRemoteBlob = self.msg!
        }
        
        saveToCoreData(remoteBlob: encryptedRemoteBlob, localBlob: encryptedLocalBlob)
    }
    
    func saveRemotePeripheralToCoreData() throws {
        var remoteBlob = EncounterBlob()
        remoteBlob.modelP = self.modelP
        remoteBlob.msg = self.msg
        var localBlob = EncounterBlob()
        localBlob.modelC = self.modelC
        localBlob.rssi = self.rssi
        localBlob.txPower = self.txPower
        
        var encryptedLocalBlob: String
        var encryptedRemoteBlob: String
        let localJson = try JSONEncoder().encode(localBlob)
        encryptedLocalBlob = try Crypto.encrypt(dataToEncrypt: localJson)
        if v == 1 {
            let remoteJson = try JSONEncoder().encode(remoteBlob)
            encryptedRemoteBlob = try Crypto.encrypt(dataToEncrypt: remoteJson)
        } else {
            encryptedRemoteBlob = self.msg!
        }
        
        saveToCoreData(remoteBlob: encryptedRemoteBlob, localBlob: encryptedLocalBlob)
    }
    
    private func saveToCoreData(remoteBlob: String, localBlob: String) {
        DispatchQueue.main.async {
            guard let persistentContainer = EncounterDB.shared.persistentContainer else {
                return
            }
            let managedContext = persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: "Encounter", in: managedContext)!
            let encounter = Encounter(entity: entity, insertInto: managedContext)
            encounter.set(encounterStruct: self, remoteBlob: remoteBlob, localBlob: localBlob)
            do {
                try managedContext.save()
            } catch {
                print("Could not save. \(error)")
            }
            NotificationCenter.default.post(name: .encounterRecorded, object: nil)
        }
    }
    
}
