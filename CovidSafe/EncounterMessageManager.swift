import Foundation
import CoreBluetooth

struct CentralWriteData: Codable {
    var modelC: String // phone model of central
    var rssi: Double
    var txPower: Double?
    var msg: String // tempID
    var org: String
    var v: Int
}

public struct PeripheralCharacteristicsData: Codable {
    var modelP: String // phone model of peripheral
    var msg: String // tempID
    var org: String
    var v: Int
}

class EncounterMessageManager {
    let userDefaultsTempIdKey = "BROADCAST_MSG"
    let userDefaultsAdvtKey = "ADVT_DATA"
    let userDefaultsAdvtExpiryKey = "ADVT_EXPIRY"
    
    struct CachedPayload {
        var payload: Data,
        expiry: TimeInterval
    }

    private var payloadLookaside = [UUID: CachedPayload]()
    
    static let shared = EncounterMessageManager()
    
    var tempId: String? {
        return UserDefaults.standard.string(forKey: userDefaultsTempIdKey)
    }
    
    var advertisedPayload: Data? {
        do {
            let broadcastPayload = EncounterBlob(modelC: nil,
                                                 rssi: nil,
                                                 txPower: nil,
                                                 modelP: DeviceIdentifier.getModel(),
                                                 msg: tempId,
                                                 timestamp: Date().timeIntervalSince1970)
            let jsonMsg = try JSONEncoder().encode(broadcastPayload)
            let encryptedJsonMsg = try Crypto.encrypt(dataToEncrypt: jsonMsg)
            let peripheralCharStruct = PeripheralCharacteristicsData(modelP: BluetraceConfig.DummyModel, msg: encryptedJsonMsg, org: BluetraceConfig.OrgID, v: BluetraceConfig.ProtocolVersion)
            return try JSONEncoder().encode(peripheralCharStruct)
        } catch {
            return nil
        }
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
            return
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
    
    fileprivate func cleanUpExpiredCachedPayloads() {
        for payloadKey in payloadLookaside.keys {
            let currentTime = Date().timeIntervalSince1970
            guard let payload = payloadLookaside[payloadKey], payload.expiry < currentTime else {
                continue
            }
            // if payload exists and expiry time is less than current time, remove.
            payloadLookaside.removeValue(forKey: payloadKey)
        }
    }
    
    func getWritePayloadForCentral(device: BLEDevice, onComplete: @escaping (Data?) -> Void) {
        guard let rssi = device.rssi else {
            DLog("getWritePayloadForCentral failed, no rssi")
            onComplete(nil)
            return
        }
        guard device.legacyPayloadCharacteristic != nil else {
            DLog("getWritePayloadForCentral failed, no legacyPayloadCharacteristic")
            onComplete(nil)
            return
        }
        getTempId { (result) in
            guard let tempId = result else {
                DLog("getWritePayloadForCentral failed, no tempid")
                onComplete(nil)
                return
            }
            var txPower: Double? = nil
            if let bleTxPower = device.txPower {
                txPower = Double(bleTxPower)
            }

            let encounterToBroadcast = EncounterBlob(modelC: DeviceIdentifier.getModel(),
                                                     rssi: Double(rssi),
                                                     txPower: txPower,
                                                     modelP: nil,
                                                     msg: tempId,
                                                     timestamp: Date().timeIntervalSince1970)

            
            do {
                let jsonMsg = try JSONEncoder().encode(encounterToBroadcast)
                let encryptedMsg = try Crypto.encrypt(dataToEncrypt: jsonMsg)
                let dataToWrite = CentralWriteData(modelC: BluetraceConfig.DummyModel,
                                                   rssi: Double(BluetraceConfig.DummyRSSI),
                                                   txPower: Double(BluetraceConfig.DummyTxPower),
                                                   msg:  encryptedMsg,
                                                   org: BluetraceConfig.OrgID,
                                                   v: BluetraceConfig.ProtocolVersion)
                let encodedData = try JSONEncoder().encode(dataToWrite)
                onComplete(encodedData)
            } catch {
                DLog("Error: \(error)")
            }
        }
    }
    
    func getAdvertisementPayload(identifier: UUID, offset: Int, onComplete: @escaping (Data?) -> Void) {
        cleanUpExpiredCachedPayloads()
        guard offset > 0 else {
            // new request coming in
            getAdvertisementPayload{ (payloadToAdvertise) in
                if let payload = payloadToAdvertise {
                    self.payloadLookaside[identifier] = CachedPayload(payload: payload, expiry: Date().timeIntervalSince1970 + BluetraceConfig.PayloadExpiry);
                }
                onComplete(payloadToAdvertise)
            }
            return
        }
        guard let cachedPayload = self.payloadLookaside[identifier] else {
            // subsequent request but nothing cached
            onComplete(nil)
            return
        }
        onComplete(cachedPayload.payload)
    }
    
    func getLastKnownAdvertisementPayload(identifier: UUID) -> Data? {
        guard let cachedPayload = self.payloadLookaside[identifier] else {
            return nil
        }
        return cachedPayload.payload
    }
    
    // this will give herald the payload it's after
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
                UserDefaults.standard.set(response.tempId, forKey: self.userDefaultsTempIdKey)
                UserDefaults.standard.set(response.expiry, forKey: self.userDefaultsAdvtExpiryKey)
                
                if let newPayload = self.advertisedPayload {
                    onComplete(newPayload)
                    return
                }
                onComplete(nil)
            }
            return
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
        GetTempIdAPI.getTempId { (tempId: String?, expiry: Int?, error: Error?, covidSafeError: CovidSafeAPIError?) in
            guard error == nil else {
                if let error = error as NSError? {
                    let code = error.code
                    let message = error.localizedDescription
                    let details = error.userInfo
                    DLog("API error. Code: \(String(describing: code)), Message: \(message), Details: \(String(describing: details))")
                } else {
                    DLog("Cloud function error, unable to convert error to NSError.\(error!)")
                }
                
                if covidSafeError == .TokenExpiredError {
                    onComplete?(CovidSafeAPIError.TokenExpiredError, nil)
                    return
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
}


extension EncounterMessageManager: PayloadDataSupplier {
    
    func payload(_ timestamp: PayloadTimestamp) -> PayloadData {
        return advertisedPayload!
    }
    
    func payload(_ identifier: UUID, offset: Int, onComplete: @escaping (PayloadData?) -> Void) -> Void {
        getAdvertisementPayload(identifier: identifier, offset: offset, onComplete: onComplete)
    }
    
    func payload(_ data: Data) -> [PayloadData] {
        // We share only one payload at a time due to the length.
        // No need to split payloads based on length or delimiter.
        return [PayloadData(data)]
    }
    
}

public extension PayloadData {
    var shortName: String {
        do {
            let decodedPayload = try JSONDecoder().decode(PeripheralCharacteristicsData.self, from: self)
            let message = decodedPayload.msg
            return String(message.suffix(25))
        } catch {
            guard count > 0 else {
                return ""
            }
            return String(self.base64EncodedString().prefix(6))
        }
    }
}
