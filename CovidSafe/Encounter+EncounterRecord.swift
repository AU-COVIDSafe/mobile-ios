//
//  Encounter+EncounterRecord.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreData

extension EncounterRecord {
    
    func saveToCoreData() {
        DispatchQueue.main.async {
            guard let persistentContainer = EncounterDB.shared.persistentContainer else {
                return
            }
            let managedContext = appDelegate.persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: "Encounter", in: managedContext)!
            let encounter = Encounter(entity: entity, insertInto: managedContext)
            encounter.set(encounterStruct: self)
            do {
                try managedContext.save()
            } catch {
                print("Could not save. \(error)")
            }
            NotificationCenter.default.post(name: .encounterRecorded, object: nil)
        }
    }
    
}
