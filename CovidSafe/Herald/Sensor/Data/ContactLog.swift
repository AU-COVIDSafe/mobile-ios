//
//  ContactLog.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// CSV contact log for post event analysis and visualisation
class ContactLog: NSObject, SensorDelegate {
    private let textFile: TextFile
    private let dateFormatter = DateFormatter()
    
    init(filename: String) {
        textFile = TextFile(filename: filename)
        if textFile.empty() {
            textFile.write("time,sensor,id,detect,read,measure,share,visit,data")
        }
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    private func timestamp() -> String {
        let timestamp = dateFormatter.string(from: Date())
        return timestamp
    }
    
    private func csv(_ value: String) -> String {
        return TextFile.csv(value)
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        textFile.write(timestamp() + "," + sensor.rawValue + "," + csv(didDetect) + ",1,,,,,")
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        textFile.write(timestamp() + "," + sensor.rawValue + "," + csv(fromTarget) + ",,2,,,," + csv(didRead.shortName))
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier, atProximity: Proximity, withTxPower: Int?) {
        textFile.write(timestamp() + "," + sensor.rawValue + "," + csv(fromTarget) + ",,2,,,," + csv(didRead.shortName))
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        textFile.write(timestamp() + "," + sensor.rawValue + "," + csv(fromTarget) + ",,,3,,," + csv(didMeasure.description))
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier, atProximity: Proximity) {
        let prefix = timestamp() + "," + sensor.rawValue + "," + csv(fromTarget)
        didShare.forEach() { payloadData in
            textFile.write(prefix + ",,,,4,," + csv(payloadData.shortName))
        }
    }    

}
