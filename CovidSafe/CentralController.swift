//
//  CentralController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//
import Foundation
import CoreData
import CoreBluetooth
import UIKit

struct CentralWriteData: Codable {
    var modelC: String // phone model of central
    var rssi: Double
    var txPower: Double?
    var msg: String // tempID
    var org: String
    var v: Int
}

class CentralController: NSObject {
    enum CentralError: Error {
        case centralAlreadyOn
        case centralAlreadyOff
    }
    var centralDidUpdateStateCallback: ((CBManagerState) -> Void)?
    var characteristicDidReadValue: ((EncounterRecord) -> Void)?
    private let restoreIdentifierKey = "com.joelkek.tracer.central"
    private var central: CBCentralManager?
    private var recoveredPeripherals: [CBPeripheral] = []
    private var cleanupPeripherals: [CBPeripheral] = []
    private var queue: DispatchQueue
    
    // This dict is to keep track of discovered android devices, so that i do not connect to the same android device multiple times within the same BluetraceConfig.CentralScanInterval
    private var discoveredAndroidPeriManufacturerToUUIDMap = [Data: UUID]()
    
    // This dict has 2 purpose
    // 1. To store all the EncounterRecord, because the RSSI and TxPower is gotten at the didDiscoverPeripheral delegate, but the characterstic value is gotten at didUpdateValueForCharacteristic delegate
    // 2. Use to check for duplicated iphones peripheral being discovered, so that i dont connect to the same iphone again in the same scan window
    private var scannedPeripherals = [UUID: (lastUpdated: Date, peripheral: CBPeripheral, encounter: EncounterRecord)]() // stores the peripherals encountered within one scan interval
    var timerForScanning: Timer?
    private var lastCleanedScannedPeripherals = Date()
    
    public init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
        
        NotificationCenter.default.addObserver(
          forName: UIApplication.didReceiveMemoryWarningNotification,
          object: nil,
          queue: .main) { [weak self] notification in
            self?.cleanupScannedPeripherals()
        }
    }
    
    func turnOn() {
        DLog("CC requested to be turnOn")
        guard central == nil else {
            return
        }
        let options: [String: Any] = [CBCentralManagerOptionRestoreIdentifierKey: restoreIdentifierKey,
                                      CBCentralManagerOptionShowPowerAlertKey: NSNumber(true)]
        central = CBCentralManager(delegate: self, queue: self.queue, options: options )
    }
    
    func turnOff() {
        DLog("CC turnOff")
        guard central != nil else {
            return
        }
        central?.stopScan()
        central = nil
    }
    
    func shouldRecordEncounter(_ encounter: EncounterRecord) -> Bool {
        guard let scannedDate = encounter.timestamp else {
            DLog("Not recorded encounter before \(encounter)")
            return true
        }
        if abs(scannedDate.timeIntervalSinceNow) > BluetraceConfig.CentralScanInterval {
            DLog("Encounter last recorded \(abs(scannedDate.timeIntervalSinceNow)) seconds ago")
            return true
        }
        return false
    }
    
    func shouldReconnectToPeripheral(peripheral: CBPeripheral) -> Bool {
        guard peripheral.state == .disconnected else {
            return false
        }
        guard let encounteredPeripheral = scannedPeripherals[peripheral.identifier] else {
            DLog("Not previously encountered CBPeripheral \(String(describing: peripheral.name))")
            return true
        }
        guard let scannedDate = encounteredPeripheral.encounter.timestamp else {
            DLog("Not previously recorded an encounter with \(encounteredPeripheral)")
            return true
        }
        if abs(scannedDate.timeIntervalSinceNow) > BluetraceConfig.CentralScanInterval {
            DLog("Peripheral last recorded \(abs(scannedDate.timeIntervalSinceNow)) seconds ago")
            return true
        }
        return false
    }
    
    public func getState() -> CBManagerState? {
        return central?.state
    }
    
    public func logPeripheralsCount(description: String) {
        #if DEBUG
            guard let peripherals = central?.retrieveConnectedPeripherals(withServices: [BluetraceConfig.BluetoothServiceID]) else {
                return
            }
            
            var connected = 0
            var connecting = 0
            var disconnected = 0
            var disconnecting = 0
            var unknown = 0
            
            for peripheral in peripherals {
                switch peripheral.state {
                case .connecting:
                    connecting+=1
                case .connected:
                    connected+=1
                case .disconnected:
                    disconnected+=1
                case .disconnecting:
                    disconnecting+=1
                default:
                    unknown+=1
                }
            }
            
            let bleLogStr = "CC \(description) Current peripherals \nconnected: \(connected), \nconnecting: \(connecting), \ndisconnected: \(disconnected), \ndisconnecting: \(disconnecting), \nunknown: \(unknown), \nscannedPeripherals: \(scannedPeripherals.count)"
            let logRecord = BLELogRecord(message: bleLogStr)
            logRecord.saveToCoreData()
        #endif
    }
}

extension CentralController: CBCentralManagerDelegate {
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        DLog("CC willRestoreState. Central state: \(BluetraceUtils.centralStateToString(central.state))")
        recoveredPeripherals = []
        if let peripheralsObject = dict[CBCentralManagerRestoredStatePeripheralsKey] {
            let peripherals = peripheralsObject as! Array<CBPeripheral>
            DLog("CC restoring \(peripherals.count) peripherals from system.")
            logPeripheralsCount(description: "Restoring peripherals")
            for peripheral in peripherals {
                if peripheral.state == .connected {
                    // only recover connected peripherals, dispose/disconnect otherwise.
                    recoveredPeripherals.append(peripheral)
                    peripheral.delegate = self
                } else {
                    cleanupPeripherals.append(peripheral)
                }
            }
            logPeripheralsCount(description: "Done Restoring peripherals")
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralDidUpdateStateCallback?(central.state)
        switch central.state {
        case .poweredOn:
            DLog("CC Starting a scan")
            
            // for all peripherals that are not disconnected, disconnect them
            self.scannedPeripherals.forEach { (scannedPeri) in
                central.cancelPeripheralConnection(scannedPeri.value.peripheral)
            }
            // clear all peripherals, such that a new scan window can take place
            self.scannedPeripherals = [UUID: (Date, CBPeripheral, EncounterRecord)]()
            self.discoveredAndroidPeriManufacturerToUUIDMap = [Data: UUID]()
            // handle a state restoration scenario
            for recoveredPeripheral in recoveredPeripherals {
                var restoredEncounter = EncounterRecord(rssi: 0, txPower: nil)
                restoredEncounter.timestamp = nil
                scannedPeripherals.updateValue((Date(), recoveredPeripheral, restoredEncounter),
                                               forKey: recoveredPeripheral.identifier)
                central.connect(recoveredPeripheral)
            }
            
            // cant cancel peripheral when BL OFF
            for cleanupPeripheral in cleanupPeripherals {
                central.cancelPeripheralConnection(cleanupPeripheral)
            }
            cleanupPeripherals = []
            
            central.scanForPeripherals(withServices: [BluetraceConfig.BluetoothServiceID], options:nil)
            logPeripheralsCount(description: "Update state powerOn")
        default:
            DLog("State chnged to \(central.state)")
        }
    }
    
    func handlePeripheralOfUncertainStatus(_ peripheral: CBPeripheral) {
        // If not connected to Peripheral, attempt connection and exit
        if peripheral.state != .connected {
            DLog("CC handlePeripheralOfUncertainStatus not connected")
            central?.connect(peripheral)
            return
        }
        // If don't know about Peripheral's services, discover services and exit
        if peripheral.services == nil {
            DLog("CC handlePeripheralOfUncertainStatus unknown services")
            peripheral.discoverServices([BluetraceConfig.BluetoothServiceID])
            return
        }
        // If Peripheral's services don't contain targetID, disconnect and remove, then exit.
        // If it does contain targetID, discover characteristics for service
        guard let service = peripheral.services?.first(where:  { $0.uuid == BluetraceConfig.BluetoothServiceID }) else {
            DLog("CC handlePeripheralOfUncertainStatus no matching Services")
            central?.cancelPeripheralConnection(peripheral)
            return
        }
        DLog("CC handlePeripheralOfUncertainStatus discoverCharacteristics")
        peripheral.discoverCharacteristics([BluetraceConfig.BluetoothServiceID], for: service)
        // If Peripheral's service's characteristics don't contain targetID, disconnect and remove, then exit.
        // If it does contain targetID, read value for characteristic
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == BluetraceConfig.BluetoothServiceID}) else {
            DLog("CC handlePeripheralOfUncertainStatus no matching Characteristics")
            central?.cancelPeripheralConnection(peripheral)
            return
        }
        DLog("CC handlePeripheralOfUncertainStatus readValue")
        peripheral.readValue(for: characteristic)
        return
    }
    
    fileprivate func cleanupScannedPeripherals() {
       
        DLog("CC scannedPeripherals/pending connections cleanup \(scannedPeripherals.count)")
        scannedPeripherals = scannedPeripherals.filter { scannedPeripheral in
            // if has been sitting in scanned for over 2 mins, remove
            if abs(scannedPeripheral.value.lastUpdated.timeIntervalSinceNow) > BluetraceConfig.PeripheralCleanInterval {
                // expired timestamp, remove
                cleanupPeripherals.append(scannedPeripheral.value.peripheral)
                return false
            } else {
                // not yet expired timestamp, keep this scanned peripheral data
                return true
            }
        }
        
        // remove android manufacturer data where peripheral has been removed
        discoveredAndroidPeriManufacturerToUUIDMap = discoveredAndroidPeriManufacturerToUUIDMap.filter(
            { andperi in
                return !scannedPeripherals.keys.contains(andperi.value)}
        )

        
        guard let central = central else {
            DLog("CC central is nil, unable to clean peripherals at the moment")
            return
        }
        
        for cleanupPeripheral in cleanupPeripherals {
            central.cancelPeripheralConnection(cleanupPeripheral)
        }
        cleanupPeripherals = []
        lastCleanedScannedPeripherals = Date()
        DLog("CC post scannedPeripherals/pending connections cleanup \(scannedPeripherals.count)")
        return
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let debugLogs = ["CentralState": BluetraceUtils.centralStateToString(central.state),
                         "peripheral": peripheral,
                         "advertisments": advertisementData as AnyObject] as AnyObject
        
        // dispatch in bluetrace queue
        DispatchQueue.global(qos: .background).async {
            MessageAPI.getMessagesIfNeeded() { (messageResponse, error) in
                if let error = error {
                    DLog("Get messages error: \(error.localizedDescription)")
                }
                // We currently dont do anything with the response. Messages are delivered via APN
            }
        }
        
        DLog("\(debugLogs)")
        // regularly cleanup and close pending connections
        if abs(lastCleanedScannedPeripherals.timeIntervalSince(Date())) > BluetraceConfig.CentralScanInterval {
            cleanupScannedPeripherals()
        }

        var initialEncounter = EncounterRecord(rssi: RSSI.doubleValue, txPower: advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Double)
        initialEncounter.timestamp = nil
        
        // iphones will "mask" the peripheral's identifier for android devices, resulting in the same android device being discovered multiple times with different peripheral identifier. Hence Android is using use CBAdvertisementDataServiceDataKey data for identifying an android pheripheral
        // Also, check that the length is greater than 2 to prevent crash. Otherwise ignore.
        if let manuData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, manuData.count > 2 {
            let androidIdentifierData = manuData.subdata(in: 2..<manuData.count)
            if discoveredAndroidPeriManufacturerToUUIDMap.keys.contains(androidIdentifierData) {
                DLog("Android Peripheral \(peripheral) has been discovered already in this window, will not attempt to connect to it again")
                return
            } else {
                peripheral.delegate = self
                discoveredAndroidPeriManufacturerToUUIDMap.updateValue(peripheral.identifier, forKey: androidIdentifierData)
                scannedPeripherals.updateValue((Date(), peripheral, initialEncounter), forKey: peripheral.identifier)
                central.connect(peripheral)
            }
        } else {
            // Means not android device, i will check if the peripheral.identifier exist in the scannedPeripherals
            DLog("CBAdvertisementDataManufacturerDataKey Data not found. Peripheral is likely not android")
            logPeripheralsCount(description: "begin didDiscover iOS device")
            if let encounteredPeripheral = scannedPeripherals[peripheral.identifier] {
                if shouldReconnectToPeripheral(peripheral: encounteredPeripheral.peripheral) {
                    peripheral.delegate = self
                    central.connect(peripheral)
                    DLog("found previous peripheral from more than 60 seconds ago")
                } else {
                    DLog("iOS Peripheral \(peripheral) has been discovered already in this window, will not attempt to connect to it again")
                    if let scannedDate = encounteredPeripheral.encounter.timestamp {
                        DLog("It was found \(scannedDate.timeIntervalSinceNow) seconds ago")
                    }
                }
            } else {
                peripheral.delegate = self
                scannedPeripherals.updateValue((Date(), peripheral, initialEncounter), forKey: peripheral.identifier)
                central.connect(peripheral)
            }
            logPeripheralsCount(description: "finish didDiscover iOS device")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peripheralStateString = BluetraceUtils.peripheralStateToString(peripheral.state)
        DLog("CC didConnect peripheral peripheralCentral state: \(BluetraceUtils.centralStateToString(central.state)), Peripheral state: \(peripheralStateString)")
        
        guard let seenPeripheral = scannedPeripherals[peripheral.identifier], shouldRecordEncounter(seenPeripheral.encounter) else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.delegate = self
        peripheral.readRSSI()
        peripheral.discoverServices([BluetraceConfig.BluetoothServiceID])
        logPeripheralsCount(description: "didConnect peripheral")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DLog("CC didDisconnectPeripheral \(peripheral) , \(error != nil ? "error: \(error.debugDescription)" : "" )")
        
        // We check that the periferal has been scanned and that there is no error.
        // No error indicates that cancelPeripheralConnection was called.
        // An error may represent that the peripheral is out of range, BL is OFF etc. In that case we don't want to retry.
        guard scannedPeripherals[peripheral.identifier] != nil && error == nil else {
            // Remove from scanned peripherals as got diconnected due to error. Also look after memory.
            scannedPeripherals.removeValue(forKey: peripheral.identifier)
            central.cancelPeripheralConnection(peripheral)
            return
        }
        
        // only attempt to reconnect if the peripheral is in the scanned dictionary and there was no error.
        if #available(iOS 12, *) {
            let options = [CBConnectPeripheralOptionStartDelayKey: NSNumber(15)]
            central.connect(peripheral, options: options)
        }
        logPeripheralsCount(description: "didDisconnect peripheral")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DLog("CC didFailToConnect peripheral \(error != nil ? "error: \(error.debugDescription)" : "" )")
        // Remove from scanned peripherals as connection failed. Also look after memory.
        scannedPeripherals.removeValue(forKey: peripheral.identifier)
        
        // by cancelling the connection we are being extra sure the peripheral is fully
        // disconnected and not left in a pending state
        central.cancelPeripheralConnection(peripheral)
        logPeripheralsCount(description: "didFailToConnect peripheral")
    }
}

extension CentralController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let err = error {
            DLog("error: \(err)")
        }
        if error == nil {
            if let existingPeripheral = scannedPeripherals[peripheral.identifier] {
                var scannedEncounter = existingPeripheral.encounter
                scannedEncounter.rssi = RSSI.doubleValue
                scannedPeripherals.updateValue((Date(), existingPeripheral.peripheral, scannedEncounter), forKey: peripheral.identifier)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("Peripheral: \(peripheral) didModifyServices: \(invalidatedServices)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let err = error {
            DLog("error: \(err)")
        }
        guard let service = peripheral.services?.first(where:  { $0.uuid == BluetraceConfig.BluetoothServiceID }) else { return }
        peripheral.discoverCharacteristics([BluetraceConfig.BluetoothServiceID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let err = error {
            DLog("error: \(err)")
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == BluetraceConfig.BluetoothServiceID}) else { return }
        peripheral.readValue(for: characteristic)
        
        // Do not need to wait for a successful read before writing, because no data from the read is needed in the write
        if let currEncounter = scannedPeripherals[peripheral.identifier] {
            EncounterMessageManager.shared.getTempId { (result) in
                guard let tempId = result else {
                    DLog("broadcast msg not present")
                    return
                }
                guard let rssi = currEncounter.encounter.rssi else {
                    DLog("rssi should be present in \(currEncounter.encounter)")
                    return
                }
                let encounterToBroadcast = EncounterBlob(modelC: DeviceIdentifier.getModel(),
                                                         rssi: rssi,
                                                         txPower: currEncounter.encounter.txPower,
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
                    peripheral.writeValue(encodedData, for: characteristic, type: .withResponse)
                } catch {
                    DLog("Error: \(error)")
                }
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let debugLogs = ["characteristic": characteristic as AnyObject,
                         "encounter": scannedPeripherals[peripheral.identifier] as AnyObject] as AnyObject
        
        DLog("\(debugLogs)")
        guard error == nil else {
            DLog("Error: \(String(describing: error))")
            return
        }
        
        if let scannedPeri = scannedPeripherals[peripheral.identifier],
            let characteristicValue = characteristic.value,
            shouldRecordEncounter(scannedPeri.encounter) {
            do {
                let peripheralCharData = try JSONDecoder().decode(PeripheralCharacteristicsData.self, from: characteristicValue)
                var encounterStruct = scannedPeri.encounter
                encounterStruct.msg = peripheralCharData.msg
                encounterStruct.update(modelP: peripheralCharData.modelP)
                encounterStruct.org = peripheralCharData.org
                encounterStruct.v = peripheralCharData.v
                encounterStruct.timestamp = Date()
                scannedPeripherals.updateValue((Date(), scannedPeri.peripheral, encounterStruct), forKey: peripheral.identifier)
                // here the remote blob will be msg and modelp if v1, msg if v2
                // local blob will be rssi, txpower, modelc
                try encounterStruct.saveRemotePeripheralToCoreData()
                DLog("Central recorded encounter with \(String(describing: scannedPeri.peripheral.name))")
            } catch {
                DLog("Error: \(error). CharacteristicValue is \(String(data: characteristicValue, encoding: .utf8) ?? "<nil>")")
            }
        } else {
            DLog("Error: scannedPeripherals[peripheral.identifier] is \(String(describing: scannedPeripherals[peripheral.identifier])), characteristic.value is \(String(describing: characteristic.value))")
        }
        
       // regularly cleanup and close pending connections
        if (abs(lastCleanedScannedPeripherals.timeIntervalSince(Date())) > BluetraceConfig.CentralScanInterval) {
           cleanupScannedPeripherals()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        DLog("didWriteValueFor to peripheral: \(peripheral), for characteristics: \(characteristic). \(error != nil ? "error: \(error.debugDescription)" : "" )")
        central?.cancelPeripheralConnection(peripheral)
    }
}
