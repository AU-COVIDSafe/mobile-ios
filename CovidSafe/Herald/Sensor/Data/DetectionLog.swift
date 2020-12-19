//
//  DetectionLog.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import UIKit

/// CSV contact log for post event analysis and visualisation
class DetectionLog: NSObject, SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.DetectionLog")
    private let textFile: TextFile
    private let payloadData: PayloadData
    private let deviceName = UIDevice.current.name
    private let deviceOS = UIDevice.current.systemVersion
    private var payloads: Set<String> = []
    private let queue = DispatchQueue(label: "Sensor.Data.DetectionLog.Queue")
    
    init(filename: String, payloadData: PayloadData) {
        textFile = TextFile(filename: filename)
        self.payloadData = payloadData
        super.init()
        write()
    }
    
    private func csv(_ value: String) -> String {
        return TextFile.csv(value)
    }

    private func write() {
        var content = "\(csv(deviceName)),iOS,\(csv(deviceOS)),\(csv(payloadData.shortName))"
        var payloadList: [String] = []
        payloads.forEach() { payload in
            guard payload != payloadData.shortName else {
                return
            }
            payloadList.append(payload)
        }
        payloadList.sort()
        payloadList.forEach() { payload in
            content.append(",")
            content.append(csv(payload))
        }
        logger.debug("write (content=\(content))")
        content.append("\n")
        textFile.overwrite(content)
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        queue.async {
            if self.payloads.insert(didRead.shortName).inserted {
                self.logger.debug("didRead (payload=\(didRead.shortName))")
                self.write()
            }
        }
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier, atProximity: Proximity, withTxPower: Int?) {
        queue.async {
            if self.payloads.insert(didRead.shortName).inserted {
                self.logger.debug("didRead (payload=\(didRead.shortName))")
                self.write()
            }
        }
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier, atProximity: Proximity) {
        didShare.forEach() { payloadData in
            queue.async {
                if self.payloads.insert(payloadData.shortName).inserted {
                    self.logger.debug("didShare (payload=\(payloadData.shortName))")
                    self.write()
                }
            }
        }
    }    

}
