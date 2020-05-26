//
//  EncounterDB.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreData

class EncounterDB {
    static let shared = EncounterDB()
    private let modelName = "tracer"
    private var localStoreUrl: URL?
    private var _persistentContainer: CovidPersistentContainer?
    var migrationDelegate: EncounterDBMigrationProgress?
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        guard let modelURL = Bundle.main.url(forResource: self.modelName, withExtension: "momd") else {
            fatalError("Unable to Find Data Model")
        }

        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Unable to Load Data Model")
        }

        return managedObjectModel
    }()
    
    public var persistentContainer: CovidPersistentContainer? {
        get {
            if let container = _persistentContainer {
                return container
            }
            //check if we need to migrate store first
            if let localStoreUrl = self.localStoreUrl {
                if FileManager.default.fileExists(atPath: localStoreUrl.path) &&
                    store(localStoreUrl, isCompatibleWithModel: self.managedObjectModel) == false {
                    return nil // Don't return a store if it's not compatible with the model
                }
            }

            let container = CovidPersistentContainer(name: self.modelName)
            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
                if let error = error as NSError? {
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            })
            _persistentContainer = container
            return _persistentContainer
        }
    }
    
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
      
    func endBackgroundTask() {
        if(backgroundTask != .invalid){
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    func setup(migrationDelegate: EncounterDBMigrationProgress?) {
        self.migrationDelegate = migrationDelegate
        self.localStoreUrl = CovidPersistentContainer.defaultDirectoryURL().appendingPathComponent(self.modelName, isDirectory: true).appendingPathExtension("sqlite")
        migrateStoreIfNecessary(storeURL: self.localStoreUrl!, destinationModel: self.managedObjectModel)
    }
}
