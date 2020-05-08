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
    
    var didUpdateState: ((String) -> Void)?
    private let restoreIdentifierKey = "com.joelkek.tracer.peripheral"
    private let peripheralName: String
    
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
        EncounterMessageManager.shared.getAdvertisementPayload { (payloadToAdvertise) in
            if let payload = payloadToAdvertise {
                request.value = payload
                peripheral.respond(to: request, withResult: .success)
            } else {
                DLog("Error getting payload to advertise")
                peripheral.respond(to: request, withResult: .unlikelyError)
            }
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
                    encounter.saveToCoreData()
                }
            }
            peripheral.respond(to: requests[0], withResult: .success)
        } catch {
            DLog("Error: \(error)")
            peripheral.respond(to: requests[0], withResult: .unlikelyError)
        }
        
    }
}
