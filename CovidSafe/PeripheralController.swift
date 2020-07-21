import CoreBluetooth

public struct PeripheralCharacteristicsData: Codable {
    var modelP: String // phone model of peripheral
    var msg: String // tempID
    var org: String
    var v: Int
}

let TRACER_SVC_ID: CBUUID = CBUUID(string: "\(PlistHelper.getvalueFromInfoPlist(withKey: "TRACER_SVC_ID") ?? "B82AB3FC-1595-4F6A-80F0-FE094CC218F9")")
let TRACER_SVC_CHARACTERISTIC_ID = CBUUID(string: "\(PlistHelper.getvalueFromInfoPlist(withKey: "TRACER_SVC_ID") ?? "B82AB3FC-1595-4F6A-80F0-FE094CC218F9")")
let ORG_ID = "<your org id here>"
let PROTOCOL_VERSION = 1

public class PeripheralController: NSObject {
    
    enum PeripheralError: Error {
        case peripheralAlreadyOn
        case peripheralAlreadyOff
    }
    
    struct CachedPayload {
        var payload: Data,
        expiry: TimeInterval
    }

    var didUpdateState: ((String) -> Void)?
    private let encounteredCentralExpiryTime:TimeInterval = 1800.0 // 30 minutes
    private let restoreIdentifierKey = "com.joelkek.tracer.peripheral"
    private let peripheralName: String
    private var encounteredCentrals = [UUID: (EncounterRecord)]()
    private var payloadLookaside = [UUID: CachedPayload]()
    private let FREQUENCY_OF_CONNECTION_IN_S = 20.0
    private var characteristicData: PeripheralCharacteristicsData
    
    private var peripheral: CBPeripheralManager!
    private var queue: DispatchQueue
    private lazy var readableCharacteristic = CBMutableCharacteristic(type: BluetraceConfig.BluetoothServiceID, properties: [.read, .write, .writeWithoutResponse], value: nil, permissions: [.readable, .writeable])
    
    public init(peripheralName: String, queue: DispatchQueue) {
        DLog("PC init")
        self.queue = queue
        self.peripheralName = peripheralName
        self.characteristicData = PeripheralCharacteristicsData(modelP: DeviceIdentifier.getModel(), msg: "<unknown>", org: BluetraceConfig.OrgID, v: BluetraceConfig.ProtocolVersion)
        super.init()
    }
    
    public func turnOn() {
        guard peripheral == nil else {
            return
        }
        peripheral = CBPeripheralManager(delegate: self, queue: self.queue, options: [CBPeripheralManagerOptionRestoreIdentifierKey: restoreIdentifierKey, CBPeripheralManagerOptionShowPowerAlertKey: 1])
    }
    
    public func turnOff() {
        guard peripheral != nil else {
            return
        }
        peripheral.stopAdvertising()
        peripheral = nil
    }
    
    public func getState() -> String {
        return BluetraceUtils.centralStateToString(peripheral.state)
    }
}

extension PeripheralController: CBPeripheralManagerDelegate {
    
    public func peripheralManager(_ peripheral: CBPeripheralManager,
                                  willRestoreState dict: [String : Any]) {
        DLog("PC willRestoreState")
    }
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        DLog("PC peripheralManagerDidUpdateState. Current state: \(BluetraceUtils.centralStateToString(peripheral.state))")
        didUpdateState?(BluetraceUtils.centralStateToString(peripheral.state))
        guard peripheral.state == .poweredOn else { return }
        let advertisementData: [String: Any] = [CBAdvertisementDataLocalNameKey: peripheralName,
                                                CBAdvertisementDataServiceUUIDsKey: [BluetraceConfig.BluetoothServiceID]]
        let tracerService = CBMutableService(type: BluetraceConfig.BluetoothServiceID, primary: true)
        tracerService.characteristics = [readableCharacteristic]
        peripheral.removeAllServices()
        peripheral.add(tracerService)
        peripheral.startAdvertising(advertisementData)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        DLog("\(["request": request] as AnyObject)")
        let remoteCentral = request.central.identifier;
        
        // clean up expired payloads
        cleanUpExpiredCachedPayloads()
        
        if request.offset == 0 {
            // new request, create new payload
            EncounterMessageManager.shared.getAdvertisementPayload { (payloadToAdvertise) in
                self.queue.async {
                    if let payload = payloadToAdvertise {
                        // cache payload for remote
                        self.payloadLookaside[remoteCentral] = CachedPayload(payload: payload, expiry: Date().timeIntervalSince1970 + self.FREQUENCY_OF_CONNECTION_IN_S);
                        
                        
                        request.value = payload.advanced(by: request.offset)
                        peripheral.respond(to: request, withResult: .success)
                    } else {
                        DLog("Error getting payload to advertise")
                        peripheral.respond(to: request, withResult: .unlikelyError)
                    }
                }
            }
        } else {
            // get cached payload, check offset valid
            guard let cachedPayload = self.payloadLookaside[remoteCentral] else {
                peripheral.respond(to: request, withResult: .unlikelyError)
                return
            }
            
            if request.offset > cachedPayload.payload.count {
                peripheral.respond(to: request, withResult: .invalidOffset)
                return
            }
            
            if request.offset == cachedPayload.payload.count {
                // the central already read all the data in its last read request
                peripheral.respond(to: request, withResult: .success)
                return
            }
            
            // return payload as normal
            request.value = cachedPayload.payload.advanced(by: request.offset)
            peripheral.respond(to: request, withResult: .success)
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
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        let debugLogs = ["requests": requests as AnyObject,
                         "reqValue": String(data: requests[0].value!, encoding: .utf8) ?? "<nil>"] as AnyObject
        DLog("\(debugLogs)")
        do {
            for request in requests {
                if let characteristicValue = request.value {
                    let dataFromCentral = try JSONDecoder().decode(CentralWriteData.self, from: characteristicValue)
                    let encounter = EncounterRecord(from: dataFromCentral)
                    if (shouldRecordEncounterWithCentral(request.central)) {
                        try encounter.saveRemoteCentralToCoreData()
                        encounteredCentrals.updateValue(encounter, forKey: request.central.identifier)
                        removeOldEncounters()
                    } else {
                        DLog("Encounterd central too recently, not recording")
                    }
                }
            }
            peripheral.respond(to: requests[0], withResult: .success)
        } catch {
            DLog("Error: \(error)")
            peripheral.respond(to: requests[0], withResult: .unlikelyError)
        }
    }
    
    private func removeOldEncounters() {
        encounteredCentrals = encounteredCentrals.filter { (uuid, encounter) -> Bool in
            guard let encDate = encounter.timestamp else {
                return true
            }
            return abs(encDate.timeIntervalSinceNow) < encounteredCentralExpiryTime
        }
    }
    
    private func shouldRecordEncounterWithCentral(_ central: CBCentral) -> Bool {
        guard let previousEncounter = encounteredCentrals[central.identifier] else {
            return true
        }
        guard let lastEncDate = previousEncounter.timestamp else {
            return true
        }
        
        if abs(lastEncDate.timeIntervalSinceNow) > BluetraceConfig.CentralScanInterval {
            return true
        }
        return false
    }
}
