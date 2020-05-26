//
//  BluetraceConfig.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import CoreBluetooth

import Foundation

struct BluetraceConfig {
    static let BluetoothServiceID = CBUUID(string: "\(PlistHelper.getvalueFromInfoPlist(withKey: "TRACER_SVC_ID") ?? "B82AB3FC-1595-4F6A-80F0-FE094CC218F9")")
    
    static let OrgID = "AU_DTA"
    static let ProtocolVersion = 2
    
    static let CentralScanInterval = 60.0 // in seconds
    static let CentralScanDuration = 10 // in seconds
    
    static let DummyModel = ""
    static let DummyRSSI = 999
    static let DummyTxPower = 999
}
