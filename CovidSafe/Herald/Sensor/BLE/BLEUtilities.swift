//
//  BLEUtilities.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import CoreBluetooth

/**
 Extension to make the state human readable in logs.
 */
@available(iOS 10.0, *)
extension CBManagerState: CustomStringConvertible {
    /**
     Get plain text description of state.
     */
    public var description: String {
        switch self {
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        case .resetting: return ".resetting"
        case .unauthorized: return ".unauthorized"
        case .unknown: return ".unknown"
        case .unsupported: return ".unsupported"
        @unknown default: return "undefined"
        }
    }
}

extension CBPeripheralManagerState : CustomStringConvertible {
    /**
     Get plain text description of state.
     */
    public var description: String {
        switch self {
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        case .resetting: return ".resetting"
        case .unauthorized: return ".unauthorized"
        case .unknown: return ".unknown"
        case .unsupported: return ".unsupported"
        @unknown default: return "undefined"
        }
    }
}

extension CBCentralManagerState : CustomStringConvertible {
    /**
     Get plain text description of state.
     */
    public var description: String {
        switch self {
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        case .resetting: return ".resetting"
        case .unauthorized: return ".unauthorized"
        case .unknown: return ".unknown"
        case .unsupported: return ".unsupported"
        @unknown default: return "undefined"
        }
    }
}


/**
 Extension to make the state human readable in logs.
 */
extension CBPeripheralState: CustomStringConvertible {
    /**
     Get plain text description fo state.
     */
    public var description: String {
        switch self {
        case .connected: return ".connected"
        case .connecting: return ".connecting"
        case .disconnected: return ".disconnected"
        case .disconnecting: return ".disconnecting"
        @unknown default: return "undefined"
        }
    }
}

/**
 Extension to make the time intervals more human readable in code.
 */
extension TimeInterval {
    static var day: TimeInterval { get { TimeInterval(86400) } }
    static var hour: TimeInterval { get { TimeInterval(3600) } }
    static var minute: TimeInterval { get { TimeInterval(60) } }
    static var never: TimeInterval { get { TimeInterval(Int.max) } }
}

/**
 Sample statistics.
 */
class Sample {
    private var n:Int64 = 0
    private var m1:Double = 0.0
    private var m2:Double = 0.0
    private var m3:Double = 0.0
    private var m4:Double = 0.0
    
    /**
     Minimum sample value.
     */
    var min:Double? = nil
    /**
     Maximum sample value.
     */
    var max:Double? = nil
    /**
     Sample size.
     */
    var count:Int64 { get { n } }
    /**
     Mean sample value.
     */
    var mean:Double? { get { n > 0 ? m1 : nil } }
    /**
     Sample variance.
     */
    var variance:Double? { get { n > 1 ? m2 / Double(n - 1) : nil } }
    /**
     Sample standard deviation.
     */
    var standardDeviation:Double? { get { n > 1 ? sqrt(m2 / Double(n - 1)) : nil } }
    /**
     String representation of mean, standard deviation, min and max
     */
    var description: String { get {
        let sCount = n.description
        let sMean = (mean == nil ? "-" : mean!.description)
        let sStandardDeviation = (standardDeviation == nil ? "-" : standardDeviation!.description)
        let sMin = (min == nil ? "-" : min!.description)
        let sMax = (max == nil ? "-" : max!.description)
        return "count=" + sCount + ",mean=" + sMean + ",sd=" + sStandardDeviation + ",min=" + sMin + ",max=" + sMax
        } }
    
    /**
     Add sample value.
     */
    func add(_ x:Double) {
        // Sample value accumulation algorithm avoids reiterating sample to compute variance.
        let n1 = n
        n += 1
        let d = x - m1
        let d_n = d / Double(n)
        let d_n2 = d_n * d_n;
        let t = d * d_n * Double(n1);
        m1 += d_n;
        m4 += t * d_n2 * Double(n * n - 3 * n + 3) + 6 * d_n2 * m2 - 4 * d_n * m3;
        m3 += t * d_n * Double(n - 2) - 3 * d_n * m2;
        m2 += t;
        if min == nil || x < min! {
            min = x;
        }
        if max == nil || x > max! {
            max = x;
        }
    }
}

/**
 Time interval samples for collecting elapsed time statistics.
 */
class TimeIntervalSample : Sample {
    private var startTime: Date?
    private var timestamp: Date?
    var period: TimeInterval? { get {
        (startTime == nil ? nil : timestamp?.timeIntervalSince(startTime!))
        }}
    
    override var description: String { get {
        let sPeriod = (period == nil ? "-" : period!.description)
        return super.description + ",period=" + sPeriod
        }}
    
    /**
     Add elapsed time since last call to add() as sample.
     */
    func add() {
        guard timestamp != nil else {
            timestamp = Date()
            startTime = timestamp
            return
        }
        let now = Date()
        if let timestamp = timestamp {
            add(now.timeIntervalSince(timestamp))
        }
        timestamp = now
    }
}
