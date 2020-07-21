//
//  EncounterRecord.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation

struct EncounterBlob: Encodable {
    var modelC: String?
    var rssi: Double?
    var txPower: Double?
    var modelP: String?
    var msg: String?
    var timestamp: Double?
}

struct EncounterRecord: Encodable {
    var timestamp: Date?
    var msg: String?
    var modelC: String?
    private(set) var modelP: String?
    var rssi: Double?
    var txPower: Double?
    var org: String?
    var v: Int?

    mutating func update(msg: String) {
        self.msg = msg
    }

    mutating func update(modelP: String) {
        self.modelP = modelP
    }
    
    // This initializer is used when central discovered a peripheral, and need to record down the rssi and txpower, and have not yet connected with the peripheral to get the msg
    init(rssi: Double, txPower: Double?) {
        self.timestamp = Date()
        self.msg = nil
        self.modelC = DeviceIdentifier.getModel()
        self.modelP = nil
        self.rssi = rssi
        self.txPower = txPower
        self.org = nil
        self.v = nil
    }
    
    init(from centralWriteData: CentralWriteData) {
        self.timestamp = Date()
        self.msg = centralWriteData.msg
        self.modelC = centralWriteData.modelC
        self.modelP = DeviceIdentifier.getModel()
        self.rssi = centralWriteData.rssi
        self.txPower = centralWriteData.txPower
        self.org = centralWriteData.org
        self.v = centralWriteData.v
    }
    
    init(msg: String) {
        self.timestamp = Date()
        self.msg = msg
        self.modelC = nil
        self.modelP = nil
        self.rssi = nil
        self.txPower = nil
        self.org = nil
        self.v = nil
    }
}
