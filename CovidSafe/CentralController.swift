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
    private var queue: DispatchQueue
    
    // This dict is to keep track of discovered android devices, so that i do not connect to the same android device multiple times within the same BluetraceConfig.CentralScanInterval
    private var discoveredAndroidPeriManufacturerToUUIDMap = [Data: UUID]()
    
    // This dict has 2 purpose
    // 1. To store all the EncounterRecord, because the RSSI and TxPower is gotten at the didDiscoverPeripheral delegate, but the characterstic value is gotten at didUpdateValueForCharacteristic delegate
    // 2. Use to check for duplicated iphones peripheral being discovered, so that i dont connect to the same iphone again in the same scan window
    private var scannedPeripherals = [UUID: (peripheral: CBPeripheral, encounter: EncounterRecord)]() // stores the peripherals encountered within one scan interval
    var timerForScanning: Timer?
    
    public init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
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
            return true
        }
        if abs(scannedDate.timeIntervalSinceNow) > BluetraceConfig.CentralScanInterval {
            return true
        }
        return false
    }
    
    func shouldReconnectToPeripheral(peripheral: CBPeripheral) -> Bool {
        guard let encounteredPeripheral = scannedPeripherals[peripheral.identifier] else {
            return true
        }
        guard let scannedDate = encounteredPeripheral.encounter.timestamp else {
            return true
        }
        if abs(scannedDate.timeIntervalSinceNow) > BluetraceConfig.CentralScanInterval {
            return true
        }
        return false
    }
    
    public func getState() -> CBManagerState? {
        return central?.state
    }
}

extension CentralController: CBCentralManagerDelegate {
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        DLog("CC willRestoreState. Central state: \(BluetraceUtils.centralStateToString(central.state))")
        if let peripheralsObject = dict[CBCentralManagerRestoredStatePeripheralsKey] {
            let peripherals = peripheralsObject as! Array<CBPeripheral>
            DLog("CC restoring \(peripherals.count) peripherals from system.")
            for peripheral in peripherals {
                recoveredPeripherals.append(peripheral)
                peripheral.delegate = self
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralDidUpdateStateCallback?(central.state)
        switch central.state {
        case .poweredOn:
            DLog("CC Starting a scan")
            Encounter.timestamp(for: .scanningStarted)
            
            // for all peripherals that are not disconnected, disconnect them
            self.scannedPeripherals.forEach { (scannedPeri) in
                central.cancelPeripheralConnection(scannedPeri.value.peripheral)
            }
            // clear all peripherals, such that a new scan window can take place
            self.scannedPeripherals = [UUID: (CBPeripheral, EncounterRecord)]()
            self.discoveredAndroidPeriManufacturerToUUIDMap = [Data: UUID]()
            // handle a state restoration scenario
            for recoveredPeripheral in recoveredPeripherals {
                var restoredEncounter = EncounterRecord(rssi: 0, txPower: nil)
                restoredEncounter.timestamp = nil
                scannedPeripherals.updateValue((recoveredPeripheral, restoredEncounter),
                                               forKey: recoveredPeripheral.identifier)
                central.connect(recoveredPeripheral)
            }
            
            central.scanForPeripherals(withServices: [BluetraceConfig.BluetoothServiceID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(true)])
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
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let debugLogs = ["CentralState": BluetraceUtils.centralStateToString(central.state),
                         "peripheral": peripheral,
                         "advertisments": advertisementData as AnyObject] as AnyObject
        
        DLog("\(debugLogs)")
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
                scannedPeripherals.updateValue((peripheral, initialEncounter), forKey: peripheral.identifier)
                central.connect(peripheral)
            }
        } else {
            // Means not android device, i will check if the peripheral.identifier exist in the scannedPeripherals
            DLog("CBAdvertisementDataManufacturerDataKey Data not found. Peripheral is likely not android")
            if let encounteredPeripheral = scannedPeripherals[peripheral.identifier] {
                if shouldReconnectToPeripheral(peripheral: encounteredPeripheral.peripheral) {
                    peripheral.delegate = self
                    if peripheral.state != .connected {
                        central.connect(peripheral)
                        DLog("found previous peripheral from more than 60 seconds ago")
                    }
                } else {
                    DLog("iOS Peripheral \(peripheral) has been discovered already in this window, will not attempt to connect to it again")
                    if let scannedDate = encounteredPeripheral.encounter.timestamp {
                        DLog("It was found \(scannedDate.timeIntervalSinceNow) seconds ago")
                    }
                }
            } else {
                peripheral.delegate = self
                scannedPeripherals.updateValue((peripheral, initialEncounter), forKey: peripheral.identifier)
                central.connect(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peripheralStateString = BluetraceUtils.peripheralStateToString(peripheral.state)
        DLog("CC didConnect peripheral peripheralCentral state: \(BluetraceUtils.centralStateToString(central.state)), Peripheral state: \(peripheralStateString)")
        guard shouldReconnectToPeripheral(peripheral: peripheral) else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.delegate = self
        peripheral.readRSSI()
        peripheral.discoverServices([BluetraceConfig.BluetoothServiceID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DLog("CC didDisconnectPeripheral \(peripheral) , \(error != nil ? "error: \(error.debugDescription)" : "" )")
        if #available(iOS 12, *) {
            let options = [CBConnectPeripheralOptionStartDelayKey: NSNumber(15)]
            central.connect(peripheral, options: options)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DLog("CC didFailToConnect peripheral \(error != nil ? "error: \(error.debugDescription)" : "" )")
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
                scannedPeripherals.updateValue((existingPeripheral.peripheral, scannedEncounter), forKey: peripheral.identifier)
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
                
                let dataToWrite = CentralWriteData(modelC: DeviceIdentifier.getModel(),
                                                   rssi: rssi,
                                                   txPower: currEncounter.encounter.txPower,
                                                   msg: tempId,
                                                   org: BluetraceConfig.OrgID,
                                                   v: BluetraceConfig.ProtocolVersion)
                
                do {
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
            shouldRecordEncounter(scannedPeri.encounter)
        {
            do {
                let peripheralCharData = try JSONDecoder().decode(PeripheralCharacteristicsData.self, from: characteristicValue)
                var encounterStruct = scannedPeri.encounter
                encounterStruct.msg = peripheralCharData.msg
                encounterStruct.update(modelP: peripheralCharData.modelP)
                encounterStruct.org = peripheralCharData.org
                encounterStruct.v = peripheralCharData.v
                encounterStruct.timestamp = Date()
                scannedPeripherals.updateValue((scannedPeri.peripheral, encounterStruct), forKey: peripheral.identifier)
                encounterStruct.saveToCoreData()
                DLog("Central recorded encounter with \(String(describing: scannedPeri.peripheral.name))")
            } catch {
                DLog("Error: \(error). CharacteristicValue is \(characteristicValue)")
            }
        } else {
            DLog("Error: scannedPeripherals[peripheral.identifier] is \(String(describing: scannedPeripherals[peripheral.identifier])), characteristic.value is \(String(describing: characteristic.value))")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        DLog("didWriteValueFor to peripheral: \(peripheral), for characteristics: \(characteristic). \(error != nil ? "error: \(error.debugDescription)" : "" )")
        central?.cancelPeripheralConnection(peripheral)
    }
}
