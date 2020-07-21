//
//  BLELogRecord+BLELogSave.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreData

extension BLELogRecord {
    
    func saveToCoreData() {
        DispatchQueue.main.async {
            guard let persistentContainer = BLELogDB.shared.persistentContainer else {
                return
            }
            let managedContext = persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: "BLELog", in: managedContext)!
            let bleLog = NSManagedObject(entity: entity, insertInto: managedContext)
            bleLog.setValue(self.timestamp, forKeyPath: "timestamp")
            bleLog.setValue(self.msg, forKeyPath: "message")
            do {
                try managedContext.save()
            } catch {
                print("Could not save. \(error)")
            }
        }
    }
    
}
