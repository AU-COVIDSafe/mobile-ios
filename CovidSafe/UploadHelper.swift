//
//  UploadHelper.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreData
import KeychainSwift

final class UploadHelper {
    
    public static func uploadEncounterData(pin: String?, _ result: @escaping (UploadResult) -> Void) {
        let keychain = KeychainSwift()
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let managedContext = appDelegate.persistentContainer.viewContext
        
        let recordsFetchRequest: NSFetchRequest<Encounter> = Encounter.fetchRequestForRecords()
        
        managedContext.perform {
            guard let records = try? recordsFetchRequest.execute() else {
                DLog("Error fetching records")
                result(.Failed)
                return
            }
            
            let data = UploadFileData(records: records)

            let encoder = JSONEncoder()
            guard let json = try? encoder.encode(data) else {
                DLog("Error serializing data")
                result(.Failed)
                return
            }

            guard let jwt = keychain.get("JWT_TOKEN") else {
                DLog("Error trying to upload when not logged in")
                result(.Failed)
                return
            }
            InitiateUploadAPI.initiateUploadAPI(session: jwt, pin: pin) { (uploadResponse, error) in
                guard error == nil else {
                    if (error == .ExpireSession) {
                        result(.SessionExpired)
                        return
                    }
                    result(.InvalidCode)
                    return
                }

                guard let response = uploadResponse else {
                    // if we fail to get a link back then the otp was potentially invalid
                    result(.InvalidCode)
                    return
                }
                DataUploadS3.uploadJSONData(data: json, presignedUrl: response.UploadLink) { (isSuccessful, error) in
                    guard isSuccessful else {
                        DLog("Error uploading file - \(String(describing: error))")
                        result(.FailedUpload)
                        return
                    }
                    result(.Success)
                }
            }
        }
    }
}
