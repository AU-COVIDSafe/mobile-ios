//
//  CovidPersistentContainer.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import CoreData

class CovidPersistentContainer: NSPersistentContainer {
    override class func defaultDirectoryURL() -> URL {
        do {
            let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return appSupport.appendingPathComponent("covidsafe", isDirectory: true)
        } catch {
            return super.defaultDirectoryURL()
        }
    }
}
