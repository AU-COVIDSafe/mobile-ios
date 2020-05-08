//
//  Encounter+Util.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreData

extension Encounter {
    @nonobjc public class func deleteAll() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        appDelegate.persistentContainer.performBackgroundTask { (backgroundContext) in
            let oldFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Encounter")
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: oldFetchRequest)
            do {
                try backgroundContext.execute(batchDeleteRequest)
            } catch {
                DLog("Error deleting old data \(error)")
            }
        }
    }
}
