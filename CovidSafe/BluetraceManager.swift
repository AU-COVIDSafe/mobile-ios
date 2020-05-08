import UIKit
import CoreData
import CoreBluetooth

class BluetraceManager {
    private var peripheralController: PeripheralController!
    private var centralController: CentralController!
    var queue: DispatchQueue!
    var bluetoothDidUpdateStateCallback: ((CBManagerState) -> Void)?
    
    static let shared = BluetraceManager()
    
    private init() {
        queue = DispatchQueue(label: "BluetraceManager")
        peripheralController = PeripheralController(peripheralName: "TR", queue: queue)
        centralController = CentralController(queue: queue)
        centralController.centralDidUpdateStateCallback = centralDidUpdateStateCallback
    }
    
    func turnOn() {
        peripheralController.turnOn()
        centralController.turnOn()
    }
    
    func isBluetoothAuthorized() -> Bool {
        if #available(iOS 13.1, *) {
            return CBManager.authorization == .allowedAlways
        } else {
            return CBPeripheralManager.authorizationStatus() == .authorized
        }
    }
    
    func isBluetoothOn() -> Bool {
        return centralController.getState() == .poweredOn
    }
    
    func centralDidUpdateStateCallback(_ state: CBManagerState) {
        bluetoothDidUpdateStateCallback?(state)
    }
    
    func toggleAdvertisement(_ state: Bool) {
        if state {
            peripheralController.turnOn()
        } else {
            peripheralController.turnOff()
        }
    }
    
    func toggleScanning(_ state: Bool) {
        if state {
            centralController.turnOn()
        } else {
            centralController.turnOff()
        }
    }
}
