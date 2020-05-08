//
//  Encounter+Event.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreData

extension Encounter {

    enum Event: String, CaseIterable {
        case scanningStarted = "Scanning started"
        case scanningStopped = "Scanning stopped"
        
        case appStarted = "App started"
        case appEnteredForeground = "App entered foreground"
        case appEnteredBackground = "App entered background"
        case appTerminating = "App about to terminate"
    }
    
    static func timestamp(for event: Event) {
        DispatchQueue.main.async {
            guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
                    return
            }
            let managedContext = appDelegate.persistentContainer.viewContext
            let entity = NSEntityDescription.entity(forEntityName: "Encounter", in: managedContext)!
            let encounter = Encounter(entity: entity, insertInto: managedContext)
            encounter.msg = event.rawValue
            encounter.timestamp = Date()
            encounter.v = nil
            do {
                try managedContext.save()
            } catch {
                print("Could not save. \(error)")
            }
        }
    }
    
}
