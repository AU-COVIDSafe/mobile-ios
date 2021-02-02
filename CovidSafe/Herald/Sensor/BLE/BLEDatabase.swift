//
//  BLEDatabase.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import CoreBluetooth

/// Registry for collating fragments of information from asynchronous BLE operations.
protocol BLEDatabase {
    
    /// Add delegate for handling database events
    func add(delegate: BLEDatabaseDelegate)
    
    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ identifier: TargetIdentifier) -> BLEDevice

    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ peripheral: CBPeripheral, delegate: CBPeripheralDelegate) -> BLEDevice

    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ payload: PayloadData) -> BLEDevice
    
    /// Get if a device exists
    func hasDevice(_ payload: PayloadData) -> Bool

    /// Get all devices
    func devices() -> [BLEDevice]
    
    /// Delete device from database
    func delete(_ identifier: TargetIdentifier)
}

/// Delegate for receiving registry create/update/delete events
protocol BLEDatabaseDelegate {
    
    func bleDatabase(didCreate device: BLEDevice)
    
    func bleDatabase(didUpdate device: BLEDevice, attribute: BLEDeviceAttribute)
    
    func bleDatabase(didDelete device: BLEDevice)
}

extension BLEDatabaseDelegate {
    func bleDatabase(didCreate device: BLEDevice) {}
    
    func bleDatabase(didUpdate device: BLEDevice, attribute: BLEDeviceAttribute) {}
    
    func bleDatabase(didDelete device: BLEDevice) {}
}

class ConcreteBLEDatabase : NSObject, BLEDatabase, BLEDeviceDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "BLE.ConcreteBLEDatabase")
    private var delegates: [BLEDatabaseDelegate] = []
    private var database: [TargetIdentifier : BLEDevice] = [:]
    private var queue = DispatchQueue(label: "Sensor.BLE.ConcreteBLEDatabase")
    
    func add(delegate: BLEDatabaseDelegate) {
        delegates.append(delegate)
    }
    
    func devices() -> [BLEDevice] {
        return database.values.map { $0 }
    }
    
    func device(_ identifier: TargetIdentifier) -> BLEDevice {
        if database[identifier] == nil {
            let device = BLEDevice(identifier, delegate: self)
            database[identifier] = device
            queue.async {
                self.logger.debug("create (device=\(identifier))")
                self.delegates.forEach { $0.bleDatabase(didCreate: device) }
            }
        }
        let device = database[identifier]!
        return device
    }

    func device(_ peripheral: CBPeripheral, delegate: CBPeripheralDelegate) -> BLEDevice {
        let identifier = TargetIdentifier(peripheral: peripheral)
        if database[identifier] == nil {
            let device = BLEDevice(identifier, delegate: self)
            database[identifier] = device
            queue.async {
                self.logger.debug("create (device=\(identifier))")
                self.delegates.forEach { $0.bleDatabase(didCreate: device) }
            }
        }
        let device = database[identifier]!
        if device.peripheral != peripheral {
            device.peripheral = peripheral
            peripheral.delegate = delegate
        }
        return device
    }
    
    func device(_ payload: PayloadData) -> BLEDevice {
        if let device = database.values.filter({ $0.payloadData == payload }).first {
            return device
        }
        // Create temporary UUID, the taskRemoveDuplicatePeripherals function
        // will delete this when a direct connection to the peripheral has been
        // established
        let identifier = TargetIdentifier(UUID().uuidString)
        let placeholder = device(identifier)
        placeholder.payloadData = payload
        return placeholder
    }
    
    func hasDevice(_ payload: PayloadData) -> Bool {
        if database.values.filter({ $0.payloadData == payload }).first != nil {
            return true
        }
        return false
    }

    func delete(_ identifier: TargetIdentifier) {
        guard let device = database[identifier] else {
            return
        }
        database[identifier] = nil
        queue.async {
            self.logger.debug("delete (device=\(identifier))")
            self.delegates.forEach { $0.bleDatabase(didDelete: device) }
        }
    }
    
    // MARK:- BLEDeviceDelegate
    
    func device(_ device: BLEDevice, didUpdate attribute: BLEDeviceAttribute) {
        queue.async {
            self.logger.debug("update (device=\(device.identifier),attribute=\(attribute.rawValue))")
            self.delegates.forEach { $0.bleDatabase(didUpdate: device, attribute: attribute) }
        }
    }
}

// MARK:- BLEDatabase data

public class BLEDevice : NSObject {
    /// Device registratiion timestamp
    let createdAt: Date
    /// Last time anything changed, e.g. attribute update
    var lastUpdatedAt: Date
    /// Last time a wake up call was received from this device (iOS only)
    var lastNotifiedAt: Date = Date.distantPast
    /// Ephemeral device identifier, e.g. peripheral identifier UUID
    let identifier: TargetIdentifier
    /// Pseudo device address for tracking devices that change device identifier constantly like the Samsung A10, A20 and Note 8
    var pseudoDeviceAddress: BLEPseudoDeviceAddress? {
        didSet {
            lastUpdatedAt = Date()
        }}
    /// Delegate for listening to attribute updates events.
    let delegate: BLEDeviceDelegate
    /// CoreBluetooth peripheral object for interacting with this device.
    var peripheral: CBPeripheral? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .peripheral)
        }}
    /// Service characteristic for signalling between BLE devices, e.g. to keep awake
    var signalCharacteristic: CBCharacteristic? {
        didSet {
            if signalCharacteristic != nil {
                lastUpdatedAt = Date()
            }
            delegate.device(self, didUpdate: .signalCharacteristic)
        }}
    /// Service characteristic for reading payload data
    var payloadCharacteristic: CBCharacteristic? {
        didSet {
            if payloadCharacteristic != nil {
                lastUpdatedAt = Date()
            }
            delegate.device(self, didUpdate: .payloadCharacteristic)
        }}
    var legacyPayloadCharacteristic: CBCharacteristic? {
        didSet {
            if legacyPayloadCharacteristic != nil {
                lastUpdatedAt = Date()
            }
            delegate.device(self, didUpdate: .payloadCharacteristic)
        }}
    /// Device operating system, this is necessary for selecting different interaction procedures for each platform.
    var operatingSystem: BLEDeviceOperatingSystem = .unknown {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .operatingSystem)
        }}
    /// Device is receive only, this is necessary for filtering payload sharing data
    var receiveOnly: Bool = false {
        didSet {
            lastUpdatedAt = Date()
        }}
    /// Payload data acquired from the device via payloadCharacteristic read
    var payloadData: PayloadData? {
        didSet {
            payloadDataLastUpdatedAt = Date()
            lastUpdatedAt = payloadDataLastUpdatedAt
            delegate.device(self, didUpdate: .payloadData)
        }}
    /// Payload data last update timestamp, this is used to determine what needs to be shared with peers.
    var payloadDataLastUpdatedAt: Date = Date.distantPast
    /// Payload data already shared with this peer
    var payloadSharingData: [PayloadData] = []
    /// Most recent RSSI measurement taken by readRSSI or didDiscover.
    var rssi: BLE_RSSI? {
        didSet {
            lastUpdatedAt = Date()
            rssiLastUpdatedAt = lastUpdatedAt
            delegate.device(self, didUpdate: .rssi)
        }}
    /// RSSI last update timestamp, this is used to track last advertised at without relying on didDiscover
    var rssiLastUpdatedAt: Date = Date.distantPast
    /// Transmit power data where available (only provided by Android devices)
    var txPower: BLE_TxPower? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .txPower)
        }}
    /// Track discovered at timestamp, used by taskConnect to prioritise connection when device runs out of concurrent connection capacity
    var lastDiscoveredAt: Date = Date.distantPast
    /// Track connect request at timestamp, used by taskConnect to prioritise connection when device runs out of concurrent connection capacity
    var lastConnectRequestedAt: Date = Date.distantPast
    /// Track connected at timestamp, used by taskConnect to prioritise connection when device runs out of concurrent connection capacity
    var lastConnectedAt: Date? {
        didSet {
            // Reset lastDisconnectedAt
            lastDisconnectedAt = nil
            // Reset lastConnectionInitiationAttempt
            lastConnectionInitiationAttempt = nil
        }}
    /// Track read payload request at timestamp, used by readPayload to de-duplicate requests from asynchronous calls
        var lastReadPayloadRequestedAt: Date = Date.distantPast
    /// Track Herald initiated connection attempts - workaround for iOS peripheral caching incorrect state bug
    var lastConnectionInitiationAttempt: Date?
    /// Track disconnected at timestamp, used by taskConnect to prioritise connection when device runs out of concurrent connection capacity
    var lastDisconnectedAt: Date? {
        didSet {
            // Reset lastConnectionInitiationAttempt
            lastConnectionInitiationAttempt = nil
        }
    }

    /// Last advert timestamp, inferred from payloadDataLastUpdatedAt, payloadSharingDataLastUpdatedAt, rssiLastUpdatedAt
    var lastAdvertAt: Date { get {
            max(createdAt, lastDiscoveredAt, payloadDataLastUpdatedAt, rssiLastUpdatedAt)
        }}
    
    /// Time interval since last payload data update, this is used to identify devices that require a payload update.
    var timeIntervalSinceLastPayloadDataUpdate: TimeInterval { get {
        Date().timeIntervalSince(payloadDataLastUpdatedAt)
    }}
    
    /// Time interval since created at timestamp
    var timeIntervalSinceCreated: TimeInterval { get {
            Date().timeIntervalSince(createdAt)
        }}
    /// Time interval since last attribute value update, this is used to identify devices that may have expired and should be removed from the database.
    var timeIntervalSinceLastUpdate: TimeInterval { get {
            Date().timeIntervalSince(lastUpdatedAt)
        }}
    /// Time interval since last advert detected, this is used to detect concurrent connection quota and prioritise disconnections
    var timeIntervalSinceLastAdvert: TimeInterval { get {
        Date().timeIntervalSince(lastAdvertAt)
        }}
    /// Time interval between last connection request, this is used to priortise disconnections
    var timeIntervalSinceLastConnectRequestedAt: TimeInterval { get {
        Date().timeIntervalSince(lastConnectRequestedAt)
        }}
    /// Time interval between last connected at and last advert, this is used to estimate last period of continuous tracking, to priortise disconnections
    var timeIntervalSinceLastDisconnectedAt: TimeInterval { get {
        guard let lastDisconnectedAt = lastDisconnectedAt else {
            return Date().timeIntervalSince(createdAt)
        }
        return Date().timeIntervalSince(lastDisconnectedAt)
        }}
    /// Time interval between last connected at and last advert, this is used to estimate last period of continuous tracking, to priortise disconnections
    var timeIntervalBetweenLastConnectedAndLastAdvert: TimeInterval { get {
        guard let lastConnectedAt = lastConnectedAt, lastAdvertAt > lastConnectedAt else {
            return TimeInterval(0)
        }
        return lastAdvertAt.timeIntervalSince(lastConnectedAt)
        }}
    
    public override var description: String { get {
        return "BLEDevice[id=\(identifier),os=\(operatingSystem.rawValue),payload=\(payloadData?.shortName ?? "nil"),address=\(pseudoDeviceAddress?.data.base64EncodedString() ?? "nil")]"
        }}
    
    init(_ identifier: TargetIdentifier, delegate: BLEDeviceDelegate) {
        self.createdAt = Date()
        self.identifier = identifier
        self.delegate = delegate
        lastUpdatedAt = createdAt
    }
}

protocol BLEDeviceDelegate {
    func device(_ device: BLEDevice, didUpdate attribute: BLEDeviceAttribute)
}

enum BLEDeviceAttribute : String {
    case peripheral, signalCharacteristic, payloadCharacteristic, payloadSharingCharacteristic, operatingSystem, payloadData, rssi, txPower
}

enum BLEDeviceOperatingSystem : String {
    case android, ios, restored, unknown, shared
}

/// RSSI in dBm.
typealias BLE_RSSI = Int

typealias BLE_TxPower = Int

class BLEPseudoDeviceAddress {
    let address: Int64
    let data: Data
    var description: String { get {
        return "BLEPseudoDeviceAddress(address=\(address),data=\(data.base64EncodedString()))"
        }}
    
    init?(fromAdvertisementData: [String: Any]) {
        guard let manufacturerData = fromAdvertisementData["kCBAdvDataManufacturerData"] as? Data else {
            return nil
        }
        guard let manufacturerId = manufacturerData.uint16(0), manufacturerId == BLESensorConfiguration.manufacturerIdForSensor else {
            return nil
        }
        guard manufacturerData.count == 8 else {
            return nil
        }
        data = Data(manufacturerData.subdata(in: 2..<8))
        var longValueData = Data(repeating: 0, count: 2)
        longValueData.append(data)
        guard let longValue = longValueData.int64(0) else {
            return nil
        }
        address = Int64(longValue)
    }
}
