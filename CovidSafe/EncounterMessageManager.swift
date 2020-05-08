import Foundation

class EncounterMessageManager {
    let userDefaultsTempIdKey = "BROADCAST_MSG"
    let userDefaultsAdvtKey = "ADVT_DATA"
    let userDefaultsAdvtExpiryKey = "ADVT_EXPIRY"
    
    static let shared = EncounterMessageManager()
    
    var tempId: String? {
        return UserDefaults.standard.string(forKey: userDefaultsTempIdKey)
    }
    
    var advertisedPayload: Data? {
        return UserDefaults.standard.data(forKey: userDefaultsAdvtKey)
    }
    
    // This variable stores the expiry date of the broadcast message. At the same time, we will use this expiry date as the expiry date for the encryted advertisement payload
    var advertisementPayloadExpiry: Date? {
        return UserDefaults.standard.object(forKey: userDefaultsAdvtExpiryKey) as? Date
    }
    
    func setup() {
        // Check payload validity
        if advertisementPayloadExpiry == nil ||  Date() > advertisementPayloadExpiry! {
            // Call API to get new tempId and expiry date
            fetchTempIdFromApi { [unowned self] (error: Error?, resp:(tempId: String, expiry: Date)?) in
                guard let response = resp else {
                    DLog("No response, Error: \(String(describing: error))")
                    return
                }
                _ = self.setAdvertisementPayloadIntoUserDefaults(response)
                UserDefaults.standard.set(response.tempId, forKey: self.userDefaultsTempIdKey)
            }
        }
    }
    
    func getTempId(onComplete: @escaping (String?) -> Void) {
        // check refreshDate
        if advertisementPayloadExpiry == nil ||  Date() > advertisementPayloadExpiry! {
            fetchTempIdFromApi { [unowned self] (error: Error?, resp:(tempId: String, expiry: Date)?) in
                guard let response = resp else {
                    DLog("No response, Error: \(String(describing: error))")
                    onComplete(nil)
                    return
                }
                UserDefaults.standard.set(response.tempId, forKey: self.userDefaultsTempIdKey)
                UserDefaults.standard.set(response.expiry, forKey: self.userDefaultsAdvtExpiryKey)
                
                onComplete(response.tempId)
                return
            }
        }
        
        // we know that tempId has not expired
        if let msg = tempId {
            onComplete(msg)
        } else {
           // this is not part of usual expected flow, just run setup and be done with it
           setup()
           onComplete(nil)
        }
    }
    
    // gets the anon tempid for broadcasting
    func getAdvertisementPayload(onComplete: @escaping (Data?) -> Void) {
         // check expiry date of payload
         if advertisementPayloadExpiry == nil ||  Date() > advertisementPayloadExpiry! {
            fetchTempIdFromApi { [unowned self] (error: Error?, resp:(tempId: String, expiry: Date)?) in
                guard let response = resp else {
                    DLog("No response, Error: \(String(describing: error))")
                    onComplete(nil)
                    return
                }
                
                if let newPayload = self.setAdvertisementPayloadIntoUserDefaults(response) {
                    onComplete(newPayload)
                }
                onComplete(nil)
            }
         }
         
         // we know that payload has not expired
         if let payload = advertisedPayload {
             onComplete(payload)
         } else {
            // this is not part of usual expected flow, just run setup and be done with it
            setup()
            onComplete(nil)
         }
     }
    
    private func fetchTempIdFromApi(onComplete: ((Error?, (String, Date)?) -> Void)?) {
        DLog("Fetching tempId from API")
        GetTempIdAPI.getTempId { (tempId: String?, expiry: Int?, error: Error?) in
            guard error == nil else {
                if let error = error as NSError? {
                    let code = error.code
                    let message = error.localizedDescription
                    let details = error.userInfo
                    DLog("API error. Code: \(String(describing: code)), Message: \(message), Details: \(String(describing: details))")
                } else {
                    DLog("Cloud function error, unable to convert error to NSError.\(error!)")
                }
                // if we have an existing tempid and expiry, use that
                if let msg = self.tempId, let exp = self.advertisementPayloadExpiry {
                    onComplete?(nil, (msg, exp))
                } else {
                    onComplete?(error, nil)
                }
                return
            }

            guard let tempId = tempId,
                let expiry = expiry else {
                    DLog("Unable to get tempId or expiry from API.")
                    onComplete?(NSError(domain: "BM", code: 9999, userInfo: nil), nil)
                    return
            }

            let date = Date(timeIntervalSince1970: TimeInterval(expiry))
            onComplete?(nil, (tempId, date))
        }
    }
    
    private func setAdvertisementPayloadIntoUserDefaults(_ response: (tempId: String, expiry: Date)) -> Data? {
        let peripheralCharStruct = PeripheralCharacteristicsData(modelP: DeviceIdentifier.getModel(), msg: response.tempId, org: BluetraceConfig.OrgID, v: BluetraceConfig.ProtocolVersion)
        do {
            let encodedPeriCharStruct = try JSONEncoder().encode(peripheralCharStruct)
            UserDefaults.standard.set(encodedPeriCharStruct, forKey: self.userDefaultsAdvtKey)
            UserDefaults.standard.set(response.expiry, forKey: self.userDefaultsAdvtExpiryKey)
            return encodedPeriCharStruct
        } catch {
            DLog("Error: \(error)")
        }
        
        return nil
    }
}
