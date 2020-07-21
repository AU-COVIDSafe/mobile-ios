//
//  BLELogRecord.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import Foundation


struct BLELogRecord: Encodable {
    var timestamp: Date?
    var msg: String?

    mutating func update(msg: String) {
        self.msg = msg
    }
    
    init(message: String) {
        self.timestamp = Date()
        self.msg = message
    }
}
