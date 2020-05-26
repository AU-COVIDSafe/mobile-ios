//
//  EncounterDB+migration.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import CoreData

protocol EncounterDBMigrationProgress {
    func migrationBegun()
    func migrationComplete()
    func migrationFailed(error: Error)
}

enum MigrationError: Error {
    case unableToRetrieveSourceModel
}

extension EncounterDB {
    
    func store(_ storeURL:URL, isCompatibleWithModel model:NSManagedObjectModel) -> Bool {

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil)
            if model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
                return true
            }
        } catch {
            DLog("ERROR getting metadata from \(storeURL) \(error)")
        }
        DLog("The store is NOT compatible with the current version of the model")
        return false
    }
    
    func migrateStoreIfNecessary (storeURL:URL, destinationModel:NSManagedObjectModel) {

        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return
        }

        guard store(storeURL, isCompatibleWithModel: destinationModel) == false else {
            return
        }
        registerBackgroundTask()
        do {
            self.migrationDelegate?.migrationBegun()
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil)
            if let sourceModel = NSManagedObjectModel.mergedModel(from: [Bundle.main], forStoreMetadata: metadata) {
                //do the migration, on the background
                DispatchQueue.global(qos: .background).async {
                    do {
                        DLog("STARTING MIGRATION")
                        try self.migrateStore(store: storeURL, sourceModel: sourceModel, destinationModel: destinationModel)
                        DispatchQueue.main.async {
                            self.endBackgroundTask()
                            self.migrationDelegate?.migrationComplete()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.endBackgroundTask()
                            self.migrationDelegate?.migrationFailed(error: error)
                        }
                        DLog("Failed to migrate")
                    }
                }
            } else {
                self.endBackgroundTask()
                self.migrationDelegate?.migrationFailed(error: MigrationError.unableToRetrieveSourceModel)
            }
        } catch {
            endBackgroundTask()
            self.migrationDelegate?.migrationFailed(error: error)
            print("FAILED to get metadata \(error)")
        }
    }
    
    func migrateStore(store:URL, sourceModel:NSManagedObjectModel, destinationModel:NSManagedObjectModel) throws {
        let tempdir = store.deletingLastPathComponent()
        let tempStore = tempdir.appendingPathComponent("temp.sqlite", isDirectory: false)
        let mappingModel = NSMappingModel(from: nil, forSourceModel: sourceModel, destinationModel: destinationModel)
        let migrationManager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        let options = [NSSQLitePragmasOption: ["journal_mode":"DELETE"]]
        do {
            try migrationManager.migrateStore(from: store,
                                              sourceType: NSSQLiteStoreType,
                                              options: options,
                                              with: mappingModel,
                                              toDestinationURL: tempStore,
                                              destinationType: NSSQLiteStoreType,
                                              destinationOptions: nil)
            let psc = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)
            try psc.replacePersistentStore(at: store,
                                           destinationOptions: nil,
                                           withPersistentStoreFrom: tempStore,
                                           sourceOptions: nil,
                                           ofType: NSSQLiteStoreType)
            try psc.destroyPersistentStore(at: tempStore, ofType: NSSQLiteStoreType, options: [NSSQLitePragmasOption: ["secure_delete": true]])
            try FileManager.default.removeItem(at: tempStore)
            
            DLog("SUCCESSFULLY MIGRATED \(store) to the Current Model")
        } catch {
            DLog("FAILED MIGRATION: \(error)")
            if FileManager.default.fileExists(atPath: tempStore.path) {
                try FileManager.default.removeItem(at: tempStore)
            }
            throw error
        }
    }
}
