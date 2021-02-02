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
    
    public static func uploadEncounterData(pin: String?, _ result: @escaping (UploadResult, String?) -> Void) {
        let keychain = KeychainSwift()
        
        guard let managedContext = EncounterDB.shared.persistentContainer?.viewContext else {
            result(.Failed, "[001]")
            return
        }
        
        
        let recordsFetchRequest: NSFetchRequest<Encounter> = Encounter.fetchRequestForRecords()
        
        managedContext.perform {
            guard let records = try? recordsFetchRequest.execute() else {
                DLog("Error fetching records")
                result(.Failed, "[002]")
                return
            }
            
            let data = UploadFileData(records: records)

            let encoder = JSONEncoder()
            guard let json = try? encoder.encode(data) else {
                DLog("Error serializing data")
                result(.Failed, "[003]")
                return
            }

            guard let jwt = keychain.get("JWT_TOKEN") else {
                DLog("Error trying to upload when not logged in")
                result(.SessionExpired, "Error retrieving token, please log in.")
                return
            }
            InitiateUploadAPI.initiateUploadAPI(session: jwt, pin: pin) { (uploadResponse, error, message) in
                guard error == nil else {
                    if (error == .ExpireSession) {
                        result(.SessionExpired, message)
                        return
                    }
                    
                    if let message = message, message.contains("InvalidPin") && error == .ServerError {
                        result(.InvalidCode, message)
                        return
                    }
                    
                    result(.Failed, message)
                    return
                }

                guard let response = uploadResponse else {
                    // if we fail to get a link back then the otp was potentially invalid
                    result(.Failed, message)
                    return
                }
                DataUploadS3.uploadJSONData(data: json, presignedUrl: response.UploadLink) { (isSuccessful, error, message) in
                    guard isSuccessful else {
                        DLog("Error uploading file - \(String(describing: error))")
                        result(.FailedUpload, message)
                        return
                    }
                    result(.Success, nil)
                }
            }
        }
    }
}
