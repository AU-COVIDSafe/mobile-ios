import UIKit
import CoreData
import CoreBluetooth

class BluetraceManager: SensorDelegate {
    
    private let logger = ConcreteSensorLogger(subsystem: "Herald", category: "BluetraceManager")
    
    var sensorDidUpdateStateCallback: ((SensorState, SensorType?) -> Void)?
    
    // Payload data supplier, sensor and contact log
    var payloadDataSupplier: PayloadDataSupplier?
    var sensor: Sensor?
    
    static let shared = BluetraceManager()
    
    var bleSensorState: SensorState = .unavailable
    var awakeSensorState: SensorState = .unavailable
    
    private var didRecordPayloadData: [String:Date] = [:]
    private var didWriteLegacyPayloadData: [String:Date] = [:]
    
    func turnOnBLE() {
        payloadDataSupplier = EncounterMessageManager.shared
        if sensor == nil {
            sensor = SensorArray(payloadDataSupplier!)
            sensor?.add(delegate: self)
        }
        sensor?.start()
    }
    
    func turnOnAllSensors() {
        payloadDataSupplier = EncounterMessageManager.shared
        if sensor == nil {
            sensor = SensorArray(payloadDataSupplier!)
            sensor?.add(delegate: self)
            // we are going to turn on one at a time
            let previousSensorDidUpdateStateCallback = sensorDidUpdateStateCallback
            sensorDidUpdateStateCallback = { state, type in
                if (state == .on ) {
                    self.sensorDidUpdateStateCallback = previousSensorDidUpdateStateCallback
                    self.turnOnLocationSensor()
                }
            }
        }
        sensor?.start()
    }
    
    
    func turnOnLocationSensor() {
        guard let sensorArray = sensor as? SensorArray else {
            return
        }
        DispatchQueue.main.async {
            sensorArray.startAwakeSensor()
        }
    }
    
    func isBluetoothAuthorized() -> Bool {
        if #available(iOS 13.1, *) {
            return CBManager.authorization == .allowedAlways
        } else {
            return CBPeripheralManager.authorizationStatus() == .authorized
        }
    }
    
    func isBluetoothOn() -> Bool {
        return bleSensorState == .on
    }
    
    func isLocationOnAuthorized() -> Bool {
        return awakeSensorState == .on
    }
    
    func centralDidUpdateStateCallback(_ state: CBManagerState) {
        if state == .poweredOn {
            sensorDidUpdateStateCallback?(.on, .BLE)
        } else {
            sensorDidUpdateStateCallback?(.off, .BLE)
        }
    }
    
    func toggleAdvertisement(_ state: Bool) {
        if state {
            sensor?.start()
        } else {
            sensor?.stop()
        }
    }
    
    func toggleScanning(_ state: Bool) {
        if state {
            sensor?.start()
        } else {
            sensor?.stop()
        }
    }
    
    func cleanRecordsData( records: inout [String:Date], expiryInterval: TimeInterval) {
        let removeDataBefore = Date() - expiryInterval
        let recentDidWritePayloadData = records.filter({ $0.value >= removeDataBefore })
        records = recentDidWritePayloadData
    }
    
    func saveEncounter(payload: PayloadData, proximity: Proximity, txPower: Int? ) throws {
        let peripheralCharData = try JSONDecoder().decode(PeripheralCharacteristicsData.self, from: payload)
        var encounterStruct = EncounterRecord(rssi: proximity.value, txPower: txPower == nil ? nil : Double(txPower!))
        encounterStruct.msg = peripheralCharData.msg
        encounterStruct.update(modelP: peripheralCharData.modelP)
        encounterStruct.org = peripheralCharData.org
        encounterStruct.v = peripheralCharData.v
        encounterStruct.timestamp = Date()
        // here the remote blob will be msg and modelp if v1, msg if v2
        // local blob will be rssi, txpower, modelc
        try encounterStruct.saveRemotePeripheralToCoreData()
    }
    
    func getIdentifier(forDevice: BLEDevice) -> String {
        return forDevice.pseudoDeviceAddress != nil ? "\(forDevice.pseudoDeviceAddress!.address)" : forDevice.identifier
    }
    
    func shouldSaveEncounter(forDeviceIdentifier: String) -> Bool {
        
        guard didRecordPayloadData[forDeviceIdentifier] == nil || abs(didRecordPayloadData[forDeviceIdentifier]!.timeIntervalSinceNow) > BluetraceConfig.PeripheralPayloadSaveInterval else {
            return false
        }
        return true
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didDetect=" + didDetect.description)
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didMeasure=" + didMeasure.description + ",fromTarget=" + fromTarget.description)
        
        // Make a call to the messages API if needed.
        // Dispatch in background queue
        DispatchQueue.global(qos: .background).async {
            MessageAPI.getMessagesIfNeeded() { (messageResponse, error) in
                if let error = error {
                    DLog("Get messages error: \(error.localizedDescription)")
                }
                // We currently dont do anything with the response. Messages are delivered via APN
            }
        }
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData, forDevice: BLEDevice) {
        logger.info(sensor.rawValue + ",didMeasure=" + didMeasure.description + ",fromTarget=" + fromTarget.description + ",withPayload=" + withPayload.shortName)
        
        let deviceIdentifier = getIdentifier(forDevice: forDevice)
        guard shouldSaveEncounter(forDeviceIdentifier: deviceIdentifier) else {
            logger.info("didMeasure, skipping save as time since last saved too recet fromTarget=" + fromTarget.description)
            return
        }
        didRecordPayloadData[deviceIdentifier] = Date()
        cleanRecordsData(records: &didRecordPayloadData, expiryInterval: BluetraceConfig.PeripheralPayloadExpiry)
        do {
            logger.debug("Saving on didMeasure fromTarget=" + fromTarget.description)
            try saveEncounter(payload: withPayload, proximity: didMeasure, txPower: nil)
        } catch {
            logger.fault("ERROR "+sensor.rawValue + ",didMeasure=" + didMeasure.description + ",fromTarget=" + fromTarget.description + ",withPayload=" + withPayload.shortName )
        }

    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        do {
            let dataFromCentral = try JSONDecoder().decode(CentralWriteData.self, from: didRead)
            logger.info(sensor.rawValue + ",didRead=" + dataFromCentral.msg + ",fromTarget=" + fromTarget.description)
        } catch {
            logger.fault(sensor.rawValue + ",didRead=" + didRead.shortName + ",fromTarget=" + fromTarget.description)
        }
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier, atProximity: Proximity, withTxPower: Int?) {
        logger.info(sensor.rawValue + ",didRead=\(didRead.shortName))" + ",fromTarget=" + fromTarget.description + ",atProximity=" + atProximity.description + ",withTxPower=\(String(describing: withTxPower))")
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier, atProximity: Proximity) {
        let payloads = didShare.map { $0.shortName }
        logger.info(sensor.rawValue + ",didShare=" + payloads.description + ",fromTarget=" + fromTarget.description)
        
    }
        
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {
        logger.info(sensor.rawValue + ",didUpdateState=" + didUpdateState.rawValue)
        
        if sensor == .BLE {
            bleSensorState = didUpdateState
            sensorDidUpdateStateCallback?(didUpdateState, sensor)
        }
        
        if sensor == .AWAKE {
            awakeSensorState = didUpdateState
            sensorDidUpdateStateCallback?(didUpdateState, sensor)
        }
    }
    
    func shouldWriteToLegacyDevice(_ device: BLEDevice) -> Bool {
        
        guard device.legacyPayloadCharacteristic != nil &&
                device.payloadCharacteristic == nil else {
            return false
        }
        
        let cleanInterval = BluetraceConfig.PeripheralPayloadExpiry
        let writeInterval = BluetraceConfig.PeripheralPayloadSaveInterval
        let deviceIdentifier = getIdentifier(forDevice: device)
        cleanRecordsData(records: &didWriteLegacyPayloadData, expiryInterval: cleanInterval)
        
        guard didWriteLegacyPayloadData[deviceIdentifier] == nil || abs(didWriteLegacyPayloadData[deviceIdentifier]!.timeIntervalSinceNow) > writeInterval else {
            return false
        }
        return true
    }
    
    func didWriteToLegacyDevice(_ device: BLEDevice) {
        let deviceIdentifier = getIdentifier(forDevice: device)
        didWriteLegacyPayloadData[deviceIdentifier] = Date()
    }
}
