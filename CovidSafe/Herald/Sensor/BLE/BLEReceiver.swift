//
//  BLEReceiver.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import CoreBluetooth
import os

/**
 Beacon receiver scans for peripherals with fixed service UUID.
 */
protocol BLEReceiver : Sensor {
}

/**
 Beacon receiver scans for peripherals with fixed service UUID in foreground and background modes. Background scan
 for Android is trivial as scanForPeripherals will always return all Android devices on every call. Background scan for iOS
 devices that are transmitting in background mode is more complex, requiring an open connection to subscribe to a
 notifying characteristic that is used as trigger for keeping both iOS devices in background state (rather than suspended
 or killed). For iOS - iOS devices, on detection, the receiver will (1) write blank data to the transmitter, which triggers the
 transmitter to send a characteristic data update after 8 seconds, which in turns (2) triggers the receiver to receive a value
 update notification, to (3) create the opportunity for a read RSSI call and repeat of this looped process that keeps both
 devices awake.
 
 Please note, the iOS - iOS process is unreliable if (1) the user switches off bluetooth via Airplane mode settings, (2) the
 device reboots, and (3) it will fail completely if the app has been killed by the user. These are conditions that cannot be
 handled reliably by CoreBluetooth state restoration.
 */
class ConcreteBLEReceiver: NSObject, BLEReceiver, BLEDatabaseDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "BLE.ConcreteBLEReceiver")
    private var delegates: [SensorDelegate] = []
    private var connectionDelegate: SensorDelegate?
    /// Dedicated sequential queue for all beacon transmitter and receiver tasks.
    private let queue: DispatchQueue!
    private let delegateQueue: DispatchQueue
    /// Database of peripherals
    private let database: BLEDatabase
    /// Payload data supplier for parsing shared payloads
    private let payloadDataSupplier: PayloadDataSupplier
    /// Central manager for managing all connections, using a single manager for simplicity.
    private var central: CBCentralManager?
    /// Dummy data for writing to the transmitter to trigger state restoration or resume from suspend state to background state.
    private let emptyData = Data(repeating: 0, count: 0)
    /**
     Shifting timer for triggering peripheral scan just before the app switches from background to suspend state following a
     call to CoreBluetooth delegate methods. Apple documentation suggests the time limit is about 10 seconds.
     */
    private var scanTimer: DispatchSourceTimer?
    /// Dedicated sequential queue for the shifting timer.
    private let scanTimerQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLEReceiver.ScanTimer")
    /// Dedicated sequential queue for the actual scan call.
    private let scheduleScanQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLEReceiver.ScheduleScan")
    /// Track scan interval and up time statistics for the receiver, for debug purposes.
    private let statistics = TimeIntervalSample()
    /// Scan result queue for recording discovered devices with no immediate pending action.
    private var scanResults: [BLEDevice] = []
    
    /// Create a BLE receiver that shares the same sequential dispatch queue as the transmitter because concurrent transmit and receive
    /// operations impacts CoreBluetooth stability. The receiver and transmitter share a common database of devices to enable the transmitter
    /// to register centrals for resolution by the receiver as peripherals to create symmetric connections. The payload data supplier provides
    /// the actual payload data to be transmitted and received via BLE.
    required init(queue: DispatchQueue, delegateQueue: DispatchQueue, database: BLEDatabase, payloadDataSupplier: PayloadDataSupplier) {
        self.queue = queue
        self.delegateQueue = delegateQueue
        self.database = database
        self.payloadDataSupplier = payloadDataSupplier
        super.init()
        database.add(delegate: self)
    }
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func addConnectionDelegate(delegate: SensorDelegate) {
        connectionDelegate = delegate
    }
    
    func removeConnectionDelegate() {
        connectionDelegate = nil
    }
    
    func start() {
        logger.debug("start")
        
        if central == nil {
            self.central = CBCentralManager(delegate: self, queue: queue, options: [
                                                CBCentralManagerOptionRestoreIdentifierKey : "Sensor.BLE.ConcreteBLEReceiver",
                                                // Set this to false to stop iOS from displaying an alert if the app is opened while bluetooth is off.
                                                CBCentralManagerOptionShowPowerAlertKey : false])
        }
        // Start scanning
        if central?.state == .poweredOn {
            scan("start")
        }
    }
    
    func stop() {
        logger.debug("stop")
        guard let central = central else {
            return
        }
        guard central.isScanning else {
            logger.fault("stop denied, already stopped")
            self.central = nil
            return
        }
        // Stop scanning
        scanTimer?.cancel()
        scanTimer = nil
        queue.async {
            central.stopScan()
            self.central = nil
        }
        // Cancel all connections, the resulting didDisconnect and didFailToConnect
        database.devices().forEach() { device in
            if let peripheral = device.peripheral, peripheral.state != .disconnected {
                disconnect("stop", peripheral)
            }
        }
    }
    
    // MARK:- Scan for peripherals and initiate connection if required
    
    /// All work starts from scan loop.
    func scan(_ source: String) {
        statistics.add()
        logger.debug("scan (source=\(source),statistics={\(statistics.description)})")
        guard central?.state == .poweredOn else {
            logger.fault("scan failed, bluetooth is not powered on")
            return
        }
        // Scan for periperals advertising the sensor service.
        // This will find all Android and iOS foreground adverts
        // but it will miss the iOS background adverts unless
        // location has been enabled and screen is on for a moment.
        queue.async { self.taskScanForPeripherals() }
        // Register connected peripherals that are advertising the
        // sensor service. This catches the orphan peripherals that
        // may have been missed by CoreBluetooth during state
        // restoration or internal errors.
        queue.async { self.taskRegisterConnectedPeripherals() }
        // Resolve peripherals by device identifier obtained via
        // the transmitter. When an iOS central connects to this
        // peripheral, the transmitter code registers the central's
        // address as a new device pending resolution here to
        // establish a symmetric connection. This enables either
        // device to detect the other (e.g. with screen on)
        // and triggering both devices to detect each other.
        queue.async { self.taskResolveDevicePeripherals() }
        // Remove devices that have not been seen for a while as
        // the identifier would have changed after about 20 mins,
        // thus it is wasteful to maintain a reference.
        queue.async { self.taskRemoveExpiredDevices() }
        // Remove duplicate devices with the same payload but
        // different identifiers. This happens frequently as
        // device address changes at regular intervals as part
        // of the Bluetooth privacy feature, thus it looks like
        // a new device but is actually associated with the same
        // payload. All references to the duplicate will be
        // removed but the actual connection will be terminated
        // by CoreBluetooth, often showing an API misuse warning
        // which can be ignored.
        queue.async { self.taskRemoveDuplicatePeripherals() }
        // iOS devices are kept in background state indefinitely
        // (instead of dropping into suspended or terminated state)
        // by a series of time delayed BLE operations. While this
        // device is awake, it will write data to other iOS devices
        // to keep them awake, and vice versa.
        queue.async { self.taskWakeTransmitters() }
        // All devices have an upper limit on the number of concurrent
        // BLE connections it can maintain. For iOS, it is usually 12
        // or above. iOS devices maintain an active connection with
        // other iOS devices to keep awake and obtain regular RSSI
        // measurements, thus it can track up to 12 iOS devices at any
        // moment in time. Above this figure, this device will need
        // to rotate (disconnect/connect) connections to multiplex
        // between the iOS devices for coverage. This is unnecessary
        // for tracking Android devices as they are tracked by scan
        // only. A connection to Android is only required for reading
        // its payload upon discovery.
        queue.async { self.taskIosMultiplex() }
        // Connect to discovered devices if the device has pending tasks.
        // The vast majority of devices will be connected immediately upon
        // discovery, if they have a pending task (e.g. to establish its
        // operating system or read its payload). Devices may be discovered
        // but not have a pending task if they have already been fully
        // resolved (e.g. has operating system, payload and recent RSSI
        // measuremnet), these are placed in the scan results queue for
        // regular checking by this connect task (e.g. to read RSSI if
        // the existing value is now out of date).
        queue.async { self.taskConnect() }
        // Schedule this scan call again for execution in at least 8 seconds
        // time to repeat the scan loop. The actual call may be delayed beyond
        // the 8 second delay from this point because all terminating operations
        // (i.e. events that will eventually lead the app to enter suspended
        // state if nothing else happens) calls this function to keep the loop
        // running indefinitely. The 8 or less seconds delay was chosen to
        // ensure the scan call is activated before the app naturally enters
        // suspended state, but not so soon the loop runs too often.
        scheduleScan("scan")
    }
    
    /**
     Schedule scan for beacons after a delay of 8 seconds to start scan again just before
     state change from background to suspended. Scan is sufficient for finding Android
     devices repeatedly in both foreground and background states.
     */
    private func scheduleScan(_ source: String) {
        scheduleScanQueue.sync {
            scanTimer?.cancel()
            scanTimer = DispatchSource.makeTimerSource(queue: scanTimerQueue)
            scanTimer?.schedule(deadline: DispatchTime.now() + BLESensorConfiguration.notificationDelay)
            scanTimer?.setEventHandler { [weak self] in
                self?.scan("scheduleScan|"+source)
            }
            scanTimer?.resume()
        }
    }
    
    /**
     Scan for peripherals advertising the beacon service.
     */
    private func taskScanForPeripherals() {
        // Scan for peripherals -> didDiscover
        central?.scanForPeripherals(
            withServices: [BLESensorConfiguration.serviceUUID],
            options: [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [BLESensorConfiguration.serviceUUID]])
    }
    
    /**
     Register all connected peripherals advertising the sensor service as a device.
     */
    private func taskRegisterConnectedPeripherals() {
        central?.retrieveConnectedPeripherals(withServices: [BLESensorConfiguration.serviceUUID]).forEach() { peripheral in
            let targetIdentifier = TargetIdentifier(peripheral: peripheral)
            let device = database.device(targetIdentifier)
            if device.peripheral == nil || device.peripheral != peripheral {
                logger.debug("taskRegisterConnectedPeripherals (device=\(device))")
                _ = database.device(peripheral, delegate: self)
            }
        }
    }

    /**
     Resolve peripheral for all database devices. This enables the symmetric connection feature where connections from central to peripheral (BLETransmitter) registers the existence
     of a potential peripheral for resolution by this central (BLEReceiver).
     */
    private func taskResolveDevicePeripherals() {
        let devicesToResolve = database.devices().filter { $0.peripheral == nil }
        devicesToResolve.forEach() { device in
            guard let identifier = UUID(uuidString: device.identifier) else {
                return
            }
            
            if let peripherals = central?.retrievePeripherals(withIdentifiers: [identifier]), let peripheral = peripherals.last {
                logger.debug("taskResolveDevicePeripherals (resolved=\(device))")
                _ = database.device(peripheral, delegate: self)
            }
        }
    }
    
    /**
     Remove devices that have not been updated for over an hour, as the UUID is likely to have changed after being out of range for over 20 minutes, so it will require discovery.
     */
    private func taskRemoveExpiredDevices() {
        let devicesToRemove = database.devices().filter { Date().timeIntervalSince($0.lastUpdatedAt) > BluetraceConfig.PeripheralCleanInterval }
        devicesToRemove.forEach() { device in
            logger.debug("taskRemoveExpiredDevices (remove=\(device))")
            database.delete(device.identifier)
            if let peripheral = device.peripheral {
                disconnect("taskRemoveExpiredDevices", peripheral)
            }
        }
    }
    
    /**
     Remove devices with the same payload data but different peripherals.
     */
    private func taskRemoveDuplicatePeripherals() {
        var index: [PayloadData:BLEDevice] = [:]
        let devices = database.devices()
        devices.forEach() { device in
            guard let payloadData = device.payloadData else {
                return
            }
            guard let duplicate = index[payloadData] else {
                index[payloadData] = device
                return
            }
            var keeping = device
            if device.peripheral != nil, duplicate.peripheral == nil {
                keeping = device
            } else if duplicate.peripheral != nil, device.peripheral == nil {
                keeping = duplicate
            } else if device.payloadDataLastUpdatedAt > duplicate.payloadDataLastUpdatedAt {
                keeping = device
            } else {
                keeping = duplicate
            }
            let discarding = (keeping.identifier == device.identifier ? duplicate : device)
            index[payloadData] = keeping
            database.delete(discarding.identifier)
            self.logger.debug("taskRemoveDuplicatePeripherals (payload=\(payloadData.shortName),device=\(device.identifier),duplicate=\(duplicate.identifier),keeping=\(keeping.identifier))")
            // CoreBluetooth will eventually give warning and disconnect actual duplicate silently.
            // While calling disconnect here is cleaner but it will trigger didDiscover and
            // retain the duplicates. Expect to see message :
            // [CoreBluetooth] API MISUSE: Forcing disconnection of unused peripheral
            // <CBPeripheral: XXX, identifier = XXX, name = iPhone, state = connected>.
            // Did you forget to cancel the connection?
        }
    }
    
    /**
     Wake transmitter on all connected iOS devices
     */
    private func taskWakeTransmitters() {
        database.devices().forEach() { device in
            guard device.operatingSystem == .ios, let peripheral = device.peripheral, peripheral.state == .connected else {
                return
            }
            guard device.timeIntervalSinceLastUpdate < TimeInterval.minute else {
                // Throttle back keep awake calls when out of range, issue pending connect instead
                connect("taskWakeTransmitters", peripheral)
                return
            }
            wakeTransmitter("taskWakeTransmitters", device)
        }
    }
    
    /**
     Connect to devices and maintain concurrent connection quota
     */
    private func taskConnect() {
        // Get recently discovered devices
        let didDiscover = taskConnectScanResults()
        // Identify recently discovered devices with pending tasks : connect -> nextTask
        let hasPendingTask = didDiscover.filter({ deviceHasPendingTask($0) })
        // Identify all connected (iOS) devices to trigger refresh : connect -> nextTask
        let toBeRefreshed = database.devices().filter({ !hasPendingTask.contains($0) && $0.peripheral?.state == .connected })
        // Identify all unconnected devices with unknown operating system, these are
        // created by ConcreteBLETransmitter on characteristic write, to ensure all
        // centrals that connect to this peripheral are recorded, to enable this central
        // to attempt connection to the peripheral, thus establishing a bi-directional
        // connection. This is essential for iOS-iOS background detection, where the
        // discovery of phoneB by phoneA, and a connection from A to B, will trigger
        // B to connect to A, thus assuming location permission has been enabled, it
        // will only require screen ON at either phone to trigger bi-directional connection.
        let asymmetric = database.devices().filter({ !hasPendingTask.contains($0)
                                                    && $0.operatingSystem == .unknown
                                                    && $0.timeIntervalSinceLastUpdate < TimeInterval.minute
                                                    && $0.peripheral?.state != .connected })
        // Connect to recently discovered devices with pending tasks
        hasPendingTask.forEach() { device in
            guard let peripheral = device.peripheral else {
                return
            }
            connect("taskConnect|hasPending", peripheral);
        }
        // Refresh connection to existing devices to trigger next task
        toBeRefreshed.forEach() { device in
            guard let peripheral = device.peripheral else {
                return
            }
            connect("taskConnect|refresh", peripheral);
        }
        // Connect to unknown devices that have written to this peripheral
        asymmetric.forEach() { device in
            guard let peripheral = device.peripheral else {
                return
            }
            connect("taskConnect|asymmetric", peripheral);
        }
    }
    
    /// Empty scan results to produce a list of recently discovered devices for connection and processing
    private func taskConnectScanResults() -> [BLEDevice] {
        var set: Set<BLEDevice> = []
        var list: [BLEDevice] = []
        while let device = scanResults.popLast() {
            if set.insert(device).inserted, let peripheral = device.peripheral, peripheral.state != .connected {
                list.append(device)
                logger.debug("taskConnectScanResults, didDiscover (device=\(device))")
            }
        }
        return list
    }
    
    /// Check if device has pending task
    private func deviceHasPendingTask(_ device: BLEDevice) -> Bool {
        // Resolve operating system
        if device.operatingSystem == .unknown || device.operatingSystem == .restored {
            return true
        }
        // Read payload
        if device.payloadData == nil {
            return true
        }
        
        // Payload update
        if device.timeIntervalSinceLastPayloadDataUpdate > BluetraceConfig.PeripheralPayloadExpiry {
            return true
        }
        
        // iOS should always be connected
        if device.operatingSystem == .ios, let peripheral = device.peripheral, peripheral.state != .connected {
            return true
        }
        return false
    }
    
    /// Check if iOS device is waiting for connection and free capacity if required
    private func taskIosMultiplex() {
        // Identify iOS devices
        let devices = database.devices().filter({ $0.operatingSystem == .ios && $0.peripheral != nil })
        // Get a list of connected devices and uptime
        let connected = devices.filter({ $0.peripheral?.state == .connected }).sorted(by: { $0.timeIntervalBetweenLastConnectedAndLastAdvert > $1.timeIntervalBetweenLastConnectedAndLastAdvert })
        // Get a list of connecting devices
        let pending = devices.filter({ $0.peripheral?.state != .connected }).sorted(by: { $0.lastConnectRequestedAt < $1.lastConnectRequestedAt })
        logger.debug("taskIosMultiplex summary (connected=\(connected.count),pending=\(pending.count))")
        connected.forEach() { device in
            logger.debug("taskIosMultiplex, connected (device=\(device.description),upTime=\(device.timeIntervalBetweenLastConnectedAndLastAdvert))")
        }
        pending.forEach() { device in
            logger.debug("taskIosMultiplex, pending (device=\(device.description),downTime=\(device.timeIntervalSinceLastConnectRequestedAt))")
        }
        // Retry all pending connections if there is surplus capacity
        if connected.count < BLESensorConfiguration.concurrentConnectionQuota {
            pending.forEach() { device in
                guard let toBeConnected = device.peripheral else {
                    return
                }
                connect("taskIosMultiplex|retry", toBeConnected);
            }
        }
        // Initiate multiplexing when capacity has been reached
        guard connected.count > BLESensorConfiguration.concurrentConnectionQuota, pending.count > 0, let deviceToBeDisconnected = connected.first, let peripheralToBeDisconnected = deviceToBeDisconnected.peripheral, deviceToBeDisconnected.timeIntervalBetweenLastConnectedAndLastAdvert > TimeInterval.minute else {
            return
        }
        logger.debug("taskIosMultiplex, multiplexing (toBeDisconnected=\(deviceToBeDisconnected.description))")
        disconnect("taskIosMultiplex", peripheralToBeDisconnected)
        pending.forEach() { device in
            guard let toBeConnected = device.peripheral else {
                return
            }
            connect("taskIosMultiplex|multiplex", toBeConnected);
        }
    }

    
    /// Initiate next action on peripheral based on current state and information available
    private func taskInitiateNextAction(_ source: String, peripheral: CBPeripheral) {
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        let device = database.device(peripheral, delegate: self)
        logger.debug("time since last payload=\(device.timeIntervalSinceLastPayloadDataUpdate)")
        if device.rssi == nil {
            // 1. RSSI
            logger.debug("taskInitiateNextAction (goal=rssi,peripheral=\(targetIdentifier))")
            readRSSI("taskInitiateNextAction|" + source, peripheral)
        } else if (device.signalCharacteristic == nil || device.payloadCharacteristic == nil) && device.legacyPayloadCharacteristic == nil {
            // 2. Characteristics
            logger.debug("taskInitiateNextAction (goal=characteristics,peripheral=\(targetIdentifier))")
            discoverServices("taskInitiateNextAction|" + source, peripheral)
        } else if device.payloadData == nil {
            // 3. Payload
            logger.debug("taskInitiateNextAction (goal=payload,peripheral=\(targetIdentifier))")
            readPayload("taskInitiateNextAction|" + source, device)
        } else if device.timeIntervalSinceLastPayloadDataUpdate > BluetraceConfig.PeripheralPayloadExpiry {
            // 4. Payload update
            logger.debug("taskInitiateNextAction (goal=payloadUpdate,peripheral=\(targetIdentifier),elapsed=\(device.timeIntervalSinceLastPayloadDataUpdate))")
            readPayload("taskInitiateNextAction|" + source, device)
        } else if let delegatesToWrite = delegatesToWriteLegacyPayload(device: device) {
            // 5. Write legacy payload
            delegatesToWrite.forEach { (delegate) in
                if let peripheral = device.peripheral {
                    writeLegacyPayload("didReadRSSI", peripheral: peripheral)
                    delegate.didWriteToLegacyDevice(device)
                }
            }
        } else if device.operatingSystem != .ios {
            // 6. Disconnect Android
            logger.debug("taskInitiateNextAction (goal=disconnect|\(device.operatingSystem.rawValue),peripheral=\(targetIdentifier))")
            disconnect("taskInitiateNextAction|" + source, peripheral)
        } else {
            // 7. Scan
            logger.debug("taskInitiateNextAction (goal=scan,peripheral=\(targetIdentifier))")
            scheduleScan("taskInitiateNextAction|" + source)
        }
    }
    
    /**
     Connect peripheral. Scanning is stopped temporarily, as recommended by Apple documentation, before initiating connect, otherwise
     pending scan operations tend to take priority and connect takes longer to start. Scanning is scheduled to resume later, to ensure scan
     resumes, even if connect fails.
     */
    private func connect(_ source: String, _ peripheral: CBPeripheral) {
        let device = database.device(peripheral, delegate: self)
        logger.debug("connect (source=\(source),device=\(device))")
        guard central?.state == .poweredOn else {
            logger.fault("connect denied, central not powered on (source=\(source),device=\(device))")
            return
        }
        queue.async {
            device.lastConnectRequestedAt = Date()
            guard let central = self.central else {
                return
            }
            central.retrievePeripherals(withIdentifiers: [peripheral.identifier]).forEach {
                if $0.state != .connected {
                    // Check to see if Herald has initiated a connection attempt before
                    if let lastAttempt = device.lastConnectionInitiationAttempt {
                        // Has Herald already initiated a connect attempt?
                        if (Date() > lastAttempt + BLESensorConfiguration.connectionAttemptTimeout) {
                            // If timeout reached, force disconnect
                            self.logger.fault("connect, timeout forcing disconnect (source=\(source),device=\(device),elapsed=\(-lastAttempt.timeIntervalSinceNow))")
                            device.lastConnectionInitiationAttempt = nil
                            self.queue.async { central.cancelPeripheralConnection(peripheral) }
                        } else {
                            // If not timed out yet, keep trying
                            self.logger.debug("connect, retrying (source=\(source),device=\(device),elapsed=\(-lastAttempt.timeIntervalSinceNow))")
                            central.connect($0)
                        }
                    } else {
                        // If not, connect now
                        self.logger.debug("connect, initiation (source=\(source),device=\(device))")
                        device.lastConnectionInitiationAttempt = Date()
                        central.connect($0)
                    }
                } else {
                    self.taskInitiateNextAction("connect|" + source, peripheral: $0)
                }
            }
        }
        scheduleScan("connect")
    }
    
    /**
     Disconnect peripheral. On didDisconnect, a connect request will be made for iOS devices to maintain an open connection;
     there is no further action for Android. On didFailedToConnect, a connect request will be made for both iOS and Android
     devices as the error is likely to be transient (as described in Apple documentation), except if the error is "Device in invalid"
     then the peripheral is unregistered by removing it from the beacons table.
     */
    private func disconnect(_ source: String, _ peripheral: CBPeripheral) {
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("disconnect (source=\(source),peripheral=\(targetIdentifier))")
        guard peripheral.state == .connected || peripheral.state == .connecting else {
            logger.fault("disconnect denied, peripheral not connected or connecting (source=\(source),peripheral=\(targetIdentifier))")
            return
        }
        queue.async { self.central?.cancelPeripheralConnection(peripheral) }
    }
    
    /// Read RSSI
    private func readRSSI(_ source: String, _ peripheral: CBPeripheral) {
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("readRSSI (source=\(source),peripheral=\(targetIdentifier))")
        guard peripheral.state == .connected else {
            logger.fault("readRSSI denied, peripheral not connected (source=\(source),peripheral=\(targetIdentifier))")
            scheduleScan("readRSSI")
            return
        }
        queue.async { peripheral.readRSSI() }
    }
    
    /// Discover services
    private func discoverServices(_ source: String, _ peripheral: CBPeripheral) {
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("discoverServices (source=\(source),peripheral=\(targetIdentifier))")
        guard peripheral.state == .connected else {
            logger.fault("discoverServices denied, peripheral not connected (source=\(source),peripheral=\(targetIdentifier))")
            scheduleScan("discoverServices")
            return
        }
        queue.async { peripheral.discoverServices([BLESensorConfiguration.serviceUUID]) }
    }
    
    /// Read payload data from device
    private func readPayload(_ source: String, _ device: BLEDevice) {
        logger.debug("readPayload (source=\(source),peripheral=\(device.identifier))")
        guard let peripheral = device.peripheral, peripheral.state == .connected else {
            logger.fault("readPayload denied, peripheral not connected (source=\(source),peripheral=\(device.identifier))")
            return
        }
        guard let payloadCharacteristic = device.payloadCharacteristic != nil ? device.payloadCharacteristic : device.legacyPayloadCharacteristic  else {
            logger.fault("readPayload denied, device missing payload characteristic (source=\(source),peripheral=\(device.identifier))")
            discoverServices("readPayload", peripheral)
            return
        }
        // De-duplicate read payload requests from multiple asynchronous calls
        let timeIntervalSinceLastReadPayloadRequestedAt = Date().timeIntervalSince(device.lastReadPayloadRequestedAt)
        guard timeIntervalSinceLastReadPayloadRequestedAt > 2 else {
            logger.fault("readPayload denied, duplicate request (source=\(source),peripheral=\(device.identifier),elapsed=\(timeIntervalSinceLastReadPayloadRequestedAt)")
            return
        }
        // Initiate read payload
        device.lastReadPayloadRequestedAt = Date()
        if device.operatingSystem == .android, let peripheral = device.peripheral {
            discoverServices("readPayload|android", peripheral)
        } else {
            queue.async { peripheral.readValue(for: payloadCharacteristic) }
        }
    }
    
    /// Retrieve delegates that are required to write legacy payload to for a specific device
    private func delegatesToWriteLegacyPayload(device: BLEDevice) -> [SensorDelegate]? {
        var delegatesToWriteLegacyPayload:[SensorDelegate] = []
        delegates.forEach { (delegate) in
            if delegate.shouldWriteToLegacyDevice(device) {
                delegatesToWriteLegacyPayload.append(delegate)
            }
        }
        return delegatesToWriteLegacyPayload.count > 0 ? delegatesToWriteLegacyPayload : nil
    }
    
    /// legacy covidsafe device, existing covidsafe code will have the central \ receiver write to the peripheral after it has requested to read its payload
    private func writeLegacyPayload(_ source: String, peripheral: CBPeripheral) {
        let device = database.device(peripheral, delegate: self)
        logger.debug("writeLegacyPayload (source=\(source),peripheral=\(device.identifier))")
        
        guard device.rssi != nil else {
            logger.fault("writeLegacyPayload denied (source=\(source), rssi should be present in \(device.identifier) before write")
            return
        }
        guard let characteristic = device.legacyPayloadCharacteristic else {
            logger.fault("writeLegacyPayload denied (source=\(source),peripheral=\(device.identifier) legacyPayloadCharacteristic not present)")
            return
        }
        EncounterMessageManager.shared.getWritePayloadForCentral(device: device) { [weak self] (result) in
            self?.queue.async {
                guard let payloadToWrite = result else {
                    self?.logger.fault("writeLegacyPayload denied (source=\(source),peripheral=\(device.identifier) failed to obtain tempId)")
                    return
                }
                self?.logger.debug("writeLegacyPayload (source=\(source),peripheral=\(device.identifier) writing...)")
                peripheral.writeValue(payloadToWrite, for: characteristic, type: .withResponse)
            }
        }
    }

    /**
     Wake transmitter by writing blank data to the beacon characteristic. This will trigger the transmitter to generate a data value update notification
     in 8 seconds, which in turn will trigger this receiver to receive a didUpdateValueFor call to keep both the transmitter and receiver awake, while
     maximising the time interval between bluetooth calls to minimise power usage.
     */
    private func wakeTransmitter(_ source: String, _ device: BLEDevice) {
        guard device.operatingSystem == .ios, let peripheral = device.peripheral, let characteristic = device.signalCharacteristic else {
            return
        }
        logger.debug("wakeTransmitter (source=\(source),peripheral=\(device.identifier),write=\(characteristic.properties.contains(.write))")
        queue.async { peripheral.writeValue(self.emptyData, for: characteristic, type: .withResponse) }
    }
    
    // MARK:- BLEDatabaseDelegate
    
    func bleDatabase(didCreate device: BLEDevice) {
        // FEATURE : Symmetric connection on write
        // All CoreBluetooth delegate callbacks in BLETransmitter will register the central interacting with this peripheral
        // in the database and generate a didCreate callback here to trigger scan, which includes a task for resolving all
        // device identifiers to actual peripherals.
        scheduleScan("bleDatabase:didCreate (device=\(device.identifier))")
    }
    
    // MARK:- CBCentralManagerDelegate
    
    /// Reinstate devices following state restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        // Restore -> Populate database
        logger.debug("willRestoreState")
        self.central = central
        central.delegate = self
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restoredPeripherals {
                let targetIdentifier = TargetIdentifier(peripheral: peripheral)
                let device = database.device(peripheral, delegate: self)
                if device.operatingSystem == .unknown {
                    device.operatingSystem = .restored
                }
                if peripheral.state == .connected {
                    device.lastConnectedAt = Date()
                }
                logger.debug("willRestoreState (peripheral=\(targetIdentifier))")
            }
        }
        // Reconnection check performed in scan following centralManagerDidUpdateState:central.state == .powerOn
    }
    
    /// Start scan when bluetooth is on.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Bluetooth on -> Scan
        if (central.state == .poweredOn) {
            logger.debug("Update state (state=poweredOn))")
            delegateQueue.async {
                self.delegates.forEach({ $0.sensor(.BLE, didUpdateState: .on) })
                self.connectionDelegate?.sensor(.BLE, didUpdateState: .on)
            }
            scan("updateState")
        } else {
            if #available(iOS 10.0, *) {
                logger.debug("Update state (state=\(central.state.description))")
            } else {
                // Required for compatibility with iOS 9.3
                switch central.state {
                    case .poweredOff:
                        logger.debug("Update state (state=poweredOff)")
                    case .poweredOn:
                        logger.debug("Update state (state=poweredOn)")
                    case .resetting:
                        logger.debug("Update state (state=resetting)")
                    case .unauthorized:
                        logger.debug("Update state (state=unauthorized)")
                    case .unknown:
                        logger.debug("Update state (state=unknown)")
                    case .unsupported:
                        logger.debug("Update state (state=unsupported)")
                    default:
                        logger.debug("Update state (state=undefined)")
                }
            }
            delegateQueue.async {
                self.delegates.forEach({ $0.sensor(.BLE, didUpdateState: .off) })
                self.connectionDelegate?.sensor(.BLE, didUpdateState: .off)
            }
        }
    }
    
    /// Share payload data across devices with the same pseudo device address
    private func shareDataAcrossDevices(_ pseudoDeviceAddress: BLEPseudoDeviceAddress) {
        // Get devices with the same pseudo address created recently
        let devicesWithSamePseudoAddress = database.devices().filter({ pseudoDeviceAddress.address == $0.pseudoDeviceAddress?.address && $0.timeIntervalSinceCreated <= BLESensorConfiguration.androidAdvertRefreshTimeInterval })
        // Get device with most recent version of payload amongst these devices
        guard let mostRecentDevice = devicesWithSamePseudoAddress.filter({ $0.payloadData != nil }).sorted(by: { $0.payloadDataLastUpdatedAt > $1.payloadDataLastUpdatedAt }).first, let payloadData = mostRecentDevice.payloadData else {
            return
        }
        // Copy data to all devices with the same pseudo address
        let payloadDataLastUpdatedAt = mostRecentDevice.payloadDataLastUpdatedAt
        let devicesToCopyPayload = devicesWithSamePseudoAddress.filter({ $0.payloadData == nil })
        devicesToCopyPayload.forEach({
            $0.signalCharacteristic = mostRecentDevice.signalCharacteristic
            $0.payloadCharacteristic = mostRecentDevice.payloadCharacteristic
            $0.legacyPayloadCharacteristic = mostRecentDevice.legacyPayloadCharacteristic
            // Only Android devices have a pseudo address
            $0.operatingSystem = .android
            $0.payloadData = payloadData
            $0.payloadDataLastUpdatedAt = payloadDataLastUpdatedAt
            logger.debug("shareDataAcrossDevices, copied payload data (from=\(mostRecentDevice.description),to=\($0.description))")
        })
        // Get devices with the same payload
        let devicesWithSamePayload = database.devices().filter({ payloadData == $0.payloadData })
        // Copy pseudo address to all devices with the same payload
        let devicesToCopyAddress = devicesWithSamePayload.filter({ $0.pseudoDeviceAddress == nil })
        devicesToCopyAddress.forEach({
            $0.pseudoDeviceAddress = pseudoDeviceAddress
            logger.debug("shareDataAcrossDevices, copied pseudo address (payloadData=\(payloadData.shortName),to=\($0.description))")
        })
    }
    
    /// Device discovery will trigger connection to resolve operating system and read payload for iOS and Android devices.
    /// Connection is kept active for iOS devices for on-going RSSI measurements, and closed for Android devices, as this
    /// iOS device can rely on this discovery callback (triggered by regular scan calls) for on-going RSSI and TX power
    /// updates, thus eliminating the need to keep connections open for Android devices that can cause stability issues for
    /// Android devices.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Populate device database
        let device = database.device(peripheral, delegate: self)
        device.lastDiscoveredAt = Date()
        device.rssi = BLE_RSSI(RSSI.intValue)
        
        // We set operating system to enable discovery with legacy apps
        if let manuData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, manuData.count > 2 {
            device.operatingSystem = .android
        } else {
            device.operatingSystem = .ios
        }
        
        if let pseudoDeviceAddress = BLEPseudoDeviceAddress(fromAdvertisementData: advertisementData) {
            device.pseudoDeviceAddress = pseudoDeviceAddress
            shareDataAcrossDevices(pseudoDeviceAddress)
        }
        if let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue {
            device.txPower = BLE_TxPower(txPower)
        }
        logger.debug("didDiscover (device=\(device),rssi=\((String(describing: device.rssi))),txPower=\((String(describing: device.txPower))))")
        if deviceHasPendingTask(device) {
            connect("didDiscover", peripheral);
        } else {
            scanResults.append(device)
        }
        
        // Schedule scan (actual connect is initiated from scan via prioritisation logic)
        scheduleScan("didDiscover")
    }
    
    /// Successful connection to a device will initate the next pending action.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // connect -> readRSSI -> discoverServices
        let device = database.device(peripheral, delegate: self)
        device.lastConnectedAt = Date()
        logger.debug("didConnect (device=\(device))")
        taskInitiateNextAction("didConnect", peripheral: peripheral)
    }
    
    /// Failure to connect to a device will result in de-registration for invalid devices or reconnection attempt otherwise.
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Connect fail -> Delete | Connect
        // Failure for peripherals advertising the beacon service should be transient, so try again.
        // This is also where iOS reports invalidated devices if connect is called after restore,
        // thus offers an opportunity for house keeping.
        let device = database.device(peripheral, delegate: self)
        logger.debug("didFailToConnect (device=\(device),error=\(String(describing: error)))")
        if String(describing: error).contains("Device is invalid") {
            logger.debug("Unregister invalid device (device=\(device))")
            database.delete(device.identifier)
        } else {
            connect("didFailToConnect", peripheral)
        }
    }
    
    /// Graceful disconnection is usually caused by device going out of range or device changing identity, thus a reconnection call is initiated
    /// here for iOS devices to resume connection where possible. This is unnecessary for Android devices as they can be rediscovered by
    /// the regular scan calls. Please note, reconnection to iOS devices is likely to fail following prolonged period of being out of range as
    /// the target device is likely to have changed identity after about 20 minutes. This requires rediscovery which is impossible if the iOS device
    /// is in background state, hence the need for enabling location and screen on to trigger rediscovery (yes, its weird, but it works).
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Disconnected -> Connect if iOS
        // Keep connection only for iOS, not necessary for Android as they are always detectable
        let device = database.device(peripheral, delegate: self)
        device.lastDisconnectedAt = Date()
        logger.debug("didDisconnectPeripheral (device=\(device),error=\(String(describing: error)))")
        if device.operatingSystem == .ios {
            // Invalidate characteristics
            device.signalCharacteristic = nil
            device.payloadCharacteristic = nil
            device.legacyPayloadCharacteristic = nil
            // Reconnect
            connect("didDisconnectPeripheral", peripheral)
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    /// Read RSSI for proximity estimation.
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        // Read RSSI -> Read Code | Notify delegates -> Scan again
        // This is the primary loop for iOS after initial connection and subscription to
        // the notifying beacon characteristic. The loop is scan -> wakeTransmitter ->
        // didUpdateValueFor -> readRSSI -> notifyDelegates -> scheduleScan -> scan
        let device = database.device(peripheral, delegate: self)
        device.rssi = BLE_RSSI(RSSI.intValue)
        logger.debug("didReadRSSI (device=\(device),rssi=\(String(describing: device.rssi)),error=\(String(describing: error)))")
        taskInitiateNextAction("didReadRSSI", peripheral: peripheral)
    }
    
    /// Service discovery triggers characteristic discovery.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Discover services -> Discover characteristics | Disconnect
        let device = database.device(peripheral, delegate: self)
        logger.debug("didDiscoverServices (device=\(device),error=\(String(describing: error)))")
        guard let services = peripheral.services else {
            disconnect("didDiscoverServices|serviceEmpty", peripheral)
            return
        }
        for service in services {
            if (service.uuid == BLESensorConfiguration.serviceUUID) {
                logger.debug("didDiscoverServices, found sensor service (device=\(device))")
                queue.async {
                    peripheral.discoverCharacteristics([BLESensorConfiguration.legacyCovidsafePayloadCharacteristicUUID, BLESensorConfiguration.androidSignalCharacteristicUUID, BLESensorConfiguration.payloadCharacteristicUUID, BLESensorConfiguration.iosSignalCharacteristicUUID], for: service)
                }
                return
            }
        }
        disconnect("didDiscoverServices|serviceNotFound", peripheral)
        // The disconnect calls here shall be handled by didDisconnect which determines whether to retry for iOS or stop for Android
    }
    
    /// Characteristic discovery provides definitive classification and confirmation of device operating system to inform next actions.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Discover characteristics -> Notify delegates -> Disconnect | Wake transmitter -> Scan again
        let device = database.device(peripheral, delegate: self)
        logger.debug("didDiscoverCharacteristicsFor (device=\(device),error=\(String(describing: error)))")
        guard let characteristics = service.characteristics else {
            disconnect("didDiscoverCharacteristicsFor|characteristicEmpty", peripheral)
            return
        }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case BLESensorConfiguration.androidSignalCharacteristicUUID:
                device.operatingSystem = .android
                device.signalCharacteristic = characteristic
                logger.debug("didDiscoverCharacteristicsFor, found android signal characteristic (device=\(device))")
            case BLESensorConfiguration.iosSignalCharacteristicUUID:
                // Maintain connection with iOS devices for keep awake
                let notify = characteristic.properties.contains(.notify)
                let write = characteristic.properties.contains(.write)
                device.operatingSystem = .ios
                device.signalCharacteristic = characteristic
                queue.async {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                logger.debug("didDiscoverCharacteristicsFor, found ios signal characteristic (device=\(device),notify=\(notify),write=\(write))")
            case BLESensorConfiguration.payloadCharacteristicUUID:
                device.payloadCharacteristic = characteristic
                logger.debug("didDiscoverCharacteristicsFor, found payload characteristic (device=\(device))")
            case BLESensorConfiguration.legacyCovidsafePayloadCharacteristicUUID:
                // if we only have legacy characteristic, use it as will be a device with old version. Otherwise ignore and use new characteristics only.
                if characteristics.count == 1 {
                    device.legacyPayloadCharacteristic = characteristic
                    logger.debug("didDiscoverCharacteristicsFor, found covidsafe legacy payload characteristic (device=\(device))")
                } else {
                    logger.debug("didDiscoverCharacteristicsFor, found covidsafe legacy payload characteristic but discarding as there are more characteristics, assuming new ble (device=\(device))")
                }
            default:
                logger.fault("didDiscoverCharacteristicsFor, found unknown characteristic (device=\(device),characteristic=\(characteristic.uuid))")
            }
        }
        // Android -> Read payload
        if device.operatingSystem == .android {
            let payloadCharacteristic = device.payloadCharacteristic != nil ? device.payloadCharacteristic : device.legacyPayloadCharacteristic
            if device.payloadData == nil || device.timeIntervalSinceLastPayloadDataUpdate > BluetraceConfig.PeripheralPayloadExpiry, let characteristicToRead = payloadCharacteristic {
                device.lastReadPayloadRequestedAt = Date()
                queue.async { peripheral.readValue(for: characteristicToRead) }
            } else {
                disconnect("didDiscoverCharacteristicsFor|android", peripheral)
            }
        }
        // Always -> Scan again
        // For initial connection, the scheduleScan call would have been made just before connect.
        // It is called again here to extend the time interval between scans.
        scheduleScan("didDiscoverCharacteristicsFor")
    }
    
    /// This iOS device will write to connected iOS devices to keep them awake, and this call back provides a backup mechanism for keeping this
    /// device awake for longer in the event that other devices are no longer responding or in range.
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Wrote characteristic -> Scan again
        let device = database.device(peripheral, delegate: self)
        logger.debug("didWriteValueFor (device=\(device),error=\(String(describing: error)))")
        // For all situations, scheduleScan would have been made earlier in the chain of async calls.
        // It is called again here to extend the time interval between scans, as this is usually the
        // last call made in all paths to wake the transmitter.
        scheduleScan("didWriteValueFor")
    }
    
    /// Other iOS devices may refresh (stop/restart) their adverts at regular intervals, thus triggering this service modification callback
    /// to invalidate existing characteristics and reconnect to refresh the device data.
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // iOS only
        // Modified service -> Invalidate beacon -> Scan
        let device = database.device(peripheral, delegate: self)
        let characteristics = invalidatedServices.map { $0.characteristics }.count
        logger.debug("didModifyServices (device=\(device),characteristics=\(characteristics))")
        guard characteristics == 0 else {
            return
        }
        device.signalCharacteristic = nil
        device.payloadCharacteristic = nil
        device.legacyPayloadCharacteristic = nil
        if peripheral.state == .connected {
            discoverServices("didModifyServices", peripheral)
        } else if peripheral.state != .connecting {
            connect("didModifyServices", peripheral)
        }
    }
    
    /// All read characteristic requests will trigger this call back to handle the response.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Updated value -> Read RSSI | Read Payload
        // Beacon characteristic is writable, primarily to enable non-transmitting Android devices to submit their
        // beacon code and RSSI as data to the transmitter via GATT write. The characteristic is also notifying on
        // iOS devices, to offer a mechanism for waking receivers. The process works as follows, (1) receiver writes
        // blank data to transmitter, (2) transmitter broadcasts value update notification after 8 seconds, (3)
        // receiver is woken up to handle didUpdateValueFor notification, (4) receiver calls readRSSI, (5) readRSSI
        // call completes and schedules scan after 8 seconds, (6) scan writes blank data to all iOS transmitters.
        // Process repeats to keep both iOS transmitters and receivers awake while maximising time interval between
        // bluetooth calls to minimise power usage.
        let device = database.device(peripheral, delegate: self)
        logger.debug("didUpdateValueFor (device=\(device),characteristic=\(characteristic.uuid),error=\(String(describing: error)))")
        switch characteristic.uuid {
        case BLESensorConfiguration.iosSignalCharacteristicUUID:
            // Wake up call from transmitter
            logger.debug("didUpdateValueFor (device=\(device),characteristic=iosSignalCharacteristic,error=\(String(describing: error)))")
            device.lastNotifiedAt = Date()
            readRSSI("didUpdateValueFor", peripheral)
            return
        case BLESensorConfiguration.androidSignalCharacteristicUUID:
            // Should not happen as Android signal is not notifying
            logger.fault("didUpdateValueFor (device=\(device),characteristic=androidSignalCharacteristic,error=\(String(describing: error)))")
        case BLESensorConfiguration.payloadCharacteristicUUID, BLESensorConfiguration.legacyCovidsafePayloadCharacteristicUUID:
            // Read payload data
            logger.debug("didUpdateValueFor (device=\(device),characteristic=payloadCharacteristic,error=\(String(describing: error)))")
            if let data = characteristic.value {
                device.payloadData = PayloadData(data)
            }
            if device.operatingSystem == .android {
                disconnect("didUpdateValueFor|payload|android", peripheral)
            } 
        default:
            logger.fault("didUpdateValueFor, unknown characteristic (device=\(device),characteristic=\(characteristic.uuid),error=\(String(describing: error)))")
        }
        scheduleScan("didUpdateValueFor")
        return
    }
}

