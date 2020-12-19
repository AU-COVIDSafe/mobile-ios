//
//  BLESensor.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import CoreBluetooth

protocol BLESensor : Sensor {
}

/// Defines BLE sensor configuration data, e.g. service and characteristic UUIDs
struct BLESensorConfiguration {
    #if DEBUG
    static let logLevel: SensorLoggerLevel = .debug;
    #else
    static let logLevel: SensorLoggerLevel = .fault;
    #endif
    /**
    Service UUID for beacon service. This is a fixed UUID to enable iOS devices to find each other even
    in background mode. Android devices will need to find Apple devices first using the manufacturer code
    then discover services to identify actual beacons.
    */
    static let serviceUUID = BluetraceConfig.BluetoothServiceID
    ///Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    ///- Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static var androidSignalCharacteristicUUID = CBUUID(string: "f617b813-092e-437a-8324-e09a80821a11")
    ///Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    ///- Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static var iosSignalCharacteristicUUID = CBUUID(string: "0eb0d5f2-eae4-4a9a-8af3-a4adb02d4363")
    ///Primary payload characteristic (read) for distributing payload data from peripheral to central, e.g. identity data
    ///- Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static var payloadCharacteristicUUID = CBUUID(string: "3e98c0f8-8f05-4829-a121-43e38f8933e7")
    static let legacyCovidsafePayloadCharacteristicUUID = BluetraceConfig.BluetoothServiceID
    /// Time delay between notifications for subscribers.
    static let notificationDelay = DispatchTimeInterval.seconds(8)
    /// Time delay between advert restart
    static let advertRestartTimeInterval = TimeInterval.hour
    /// Herald internal connection expiry timeout
    static let connectionAttemptTimeout = TimeInterval(12)
    /// Expiry time for shared payloads, to ensure only recently seen payloads are shared
    /// Must be > payloadSharingTimeInterval to share pending payloads
    static let payloadSharingExpiryTimeInterval = TimeInterval.minute * 5
    /// Maximum number of concurrent BLE connections
    static let concurrentConnectionQuota = 12
    /// Manufacturer data is being used on Android to store pseudo device address
    static let manufacturerIdForSensor = UInt16(65530);
    /// Advert refresh time interval on Android devices
    static let androidAdvertRefreshTimeInterval = TimeInterval.minute * 15;
    // Filter duplicate payload data and suppress sensor(didRead:fromTarget) delegate calls
    /// - Set to .never to disable this feature
    /// - Set time interval N to filter duplicate payload data seen in last N seconds
    /// - Example : 60 means filter duplicates in last minute
    /// - Filters all occurrences of payload data from all targets
    public static var filterDuplicatePayloadData = TimeInterval(30 * 60)


    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload data length, then payload data
    static let signalCharacteristicActionWritePayload = UInt8(1)
    /// Signal characteristic action code for write RSSI, expect 1 byte action code followed by 4 byte little-endian Int32 integer value for RSSI value
    static let signalCharacteristicActionWriteRSSI = UInt8(2)
    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload sharing data length, then payload sharing data
    static let signalCharacteristicActionWritePayloadSharing = UInt8(3)
    
    /// Are Location Permissions enabled in the app, and thus awake on screen on enabled
    public static var awakeOnLocationEnabled: Bool = true
}


/**
BLE sensor based on CoreBluetooth
Requires : Signing & Capabilities : BackgroundModes : Uses Bluetooth LE accessories  = YES
Requires : Signing & Capabilities : BackgroundModes : Acts as a Bluetooth LE accessory  = YES
Requires : Info.plist : Privacy - Bluetooth Always Usage Description
Requires : Info.plist : Privacy - Bluetooth Peripheral Usage Description
*/
class ConcreteBLESensor : NSObject, BLESensor, BLEDatabaseDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "BLE.ConcreteBLESensor")
    private let sensorQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLESensor.SensorQueue")
    private let delegateQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLESensor.DelegateQueue")
    private var delegates: [SensorDelegate] = []
    private let database: BLEDatabase
    private let transmitter: BLETransmitter
    private let receiver: BLEReceiver
    // Record payload data to enable de-duplication
    private var didReadPayloadData: [PayloadData:Date] = [:]

    init(_ payloadDataSupplier: PayloadDataSupplier) {
        database = ConcreteBLEDatabase()
        transmitter = ConcreteBLETransmitter(queue: sensorQueue, delegateQueue: delegateQueue, database: database, payloadDataSupplier: payloadDataSupplier)
        receiver = ConcreteBLEReceiver(queue: sensorQueue,delegateQueue: delegateQueue, database: database, payloadDataSupplier: payloadDataSupplier)
        super.init()
        database.add(delegate: self)
    }
    
    func start() {
        logger.debug("start")
        
        var permissionRequested = false
        if #available(iOS 13.1, *) {
            permissionRequested = (CBManager.authorization != .notDetermined)
        } else {
            permissionRequested = CBPeripheralManager.authorizationStatus() != .notDetermined
        }
        
        if let receiver = receiver as? ConcreteBLEReceiver, !permissionRequested {
            // BLE receivers start on powerOn event, on status change the transmitter will be started.
            // This is to request permissions and turn on dialogs sequentially when registering
            receiver.addConnectionDelegate(delegate: self)
        }
        receiver.start()
        
        // if permissions have been requested start transmitter immediately
        if permissionRequested {
            transmitter.start()
        }
    }

    func stop() {
        logger.debug("stop")
        transmitter.stop()
        receiver.stop()
        // BLE transmitter and receivers stops on powerOff event
    }
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
        transmitter.add(delegate: delegate)
        receiver.add(delegate: delegate)
    }
    
    // MARK:- BLEDatabaseDelegate
    
    func bleDatabase(didCreate device: BLEDevice) {
        logger.debug("didDetect (device=\(device.identifier),payloadData=\(device.payloadData?.shortName ?? "nil"))")
        delegateQueue.async {
            self.delegates.forEach { $0.sensor(.BLE, didDetect: device.identifier) }
        }
    }
    
    func bleDatabase(didUpdate device: BLEDevice, attribute: BLEDeviceAttribute) {
        switch attribute {
        case .rssi:
            guard let rssi = device.rssi else {
                return
            }
            let proximity = Proximity(unit: .RSSI, value: Double(rssi))
            logger.debug("didMeasure (device=\(device.identifier),payloadData=\(device.payloadData?.shortName ?? "nil"),proximity=\(proximity.description))")
            delegateQueue.async {
                self.delegates.forEach { $0.sensor(.BLE, didMeasure: proximity, fromTarget: device.identifier) }
            }
            guard let payloadData = device.payloadData else {
                return
            }
            delegateQueue.async {
                self.delegates.forEach { $0.sensor(.BLE, didMeasure: proximity, fromTarget: device.identifier, withPayload: payloadData, forDevice: device) }
            }
        case .payloadData:
            guard let payloadData = device.payloadData else {
                return
            }
            guard device.lastReadPayloadRequestedAt != Date.distantPast else {
                logger.debug("didRead payload. lastReadPayloadRequestedAt is not set and payload has been updated. This is an android data share/copy and is ignored.")
                return
            }
            logger.debug("didRead (device=\(device.identifier),payloadData=\(payloadData.shortName))")
            guard let rssi = device.rssi else {
                logger.debug("didRead rssi is nil, not proceeding")
                return
            }
            // De-duplicate payload in recent time
            if BLESensorConfiguration.filterDuplicatePayloadData != .never {
                let removePayloadDataBefore = Date() - BLESensorConfiguration.filterDuplicatePayloadData
                let recentDidReadPayloadData = didReadPayloadData.filter({ $0.value >= removePayloadDataBefore })
                didReadPayloadData = recentDidReadPayloadData
                if let lastReportedAt = didReadPayloadData[payloadData] {
                    logger.debug("didRead, filtered duplicate (device=\(device.identifier),payloadData=\(payloadData.shortName),lastReportedAt=\(lastReportedAt.description))")
                    return
                }
                didReadPayloadData[payloadData] = Date()
            }
            
            let proximity = Proximity(unit: .RSSI, value: Double(rssi))
            delegateQueue.async {
                self.delegates.forEach { $0.sensor(.BLE, didRead: payloadData, fromTarget: device.identifier, atProximity: proximity, withTxPower: device.txPower) }
            }
        default:
            return
        }
    }
    
}

extension ConcreteBLESensor: SensorDelegate {
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {
        guard let receiver = receiver as? ConcreteBLEReceiver else {
            return
        }
        receiver.removeConnectionDelegate()
        transmitter.start()
    }
}

extension TargetIdentifier {
    init(peripheral: CBPeripheral) {
        self.init(peripheral.identifier.uuidString)
    }
    init(central: CBCentral) {
        self.init(central.identifier.uuidString)
    }
}
