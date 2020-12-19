//
//  SensorDelegate.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Sensor delegate for receiving sensor events.
public protocol SensorDelegate {
    /// Detection of a target with an ephemeral identifier, e.g. BLE central detecting a BLE peripheral.
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier)
    
    /// Read payload data from target, e.g. encrypted device identifier from BLE peripheral after successful connection.
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier)
    
    /// Read payload data of other targets recently acquired by a target, e.g. Android peripheral sharing payload data acquired from nearby iOS peripherals.
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier, atProximity: Proximity)

    /// Measure proximity to target, e.g. a sample of RSSI values from BLE peripheral.
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier)
    
    /// Measure proximity to target with payload data. Combines didMeasure and didRead into a single convenient delegate method
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData)
    
    /// Measure proximity to target with payload data. Combines didMeasure and didRead into a single convenient delegate method
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData, forDevice: BLEDevice)
    
    /// Measure proximity to target with payload data. Combines didMeasure and didRead into a single convenient delegate method
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier, atProximity: Proximity, withTxPower: Int?)
    
    /// Sensor state update
    func sensor(_ sensor: SensorType, didUpdateState: SensorState)
    
    /// Check if backwards compatibility legacy payload should be written to given device
    func shouldWriteToLegacyDevice(_ device: BLEDevice) -> Bool
    
    /// Did write backwards compatibility legacy payload to given device
    func didWriteToLegacyDevice(_ device: BLEDevice)
}

/// Sensor delegate functions are all optional.
public extension SensorDelegate {
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier, atProximity: Proximity) {}
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {}
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData, forDevice: BLEDevice) {}
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {}
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier, atProximity: Proximity, withTxPower: Int?) {}
    
    func shouldWriteToLegacyDevice(_ device: BLEDevice) -> Bool { return false }
    func didWriteToLegacyDevice(_ device: BLEDevice) {}    
}

// MARK:- SensorDelegate data

/// Sensor type as qualifier for target identifier.
public enum SensorType : String {
    /// Bluetooth Low Energy (BLE)
    case BLE
    /// Awake location sensor - uses Location API to be alerted to screen on events
    case AWAKE
    /// GPS location sensor - not used by default in Herald
    case GPS
    /// Physical beacon, e.g. iBeacon
    case BEACON
    /// Ultrasound audio beacon.
    case ULTRASOUND
}

/// Sensor state
public enum SensorState : String {
    /// Sensor is powered on, active and operational
    case on
    /// Sensor is powered off, inactive and not operational
    case off
    /// Sensor is not available
    case unavailable
}

/// Ephemeral identifier for detected target (e.g. smartphone, beacon, place). This is likely to be an UUID but using String for variable identifier length.
public typealias TargetIdentifier = String

// MARK:- Proximity data

/// Raw data for estimating proximity between sensor and target, e.g. RSSI for BLE.
public struct Proximity {
    /// Unit of measurement, e.g. RSSI
    let unit: ProximityMeasurementUnit
    /// Measured value, e.g. raw RSSI value.
    let value: Double
    /// Get plain text description of proximity data
    public var description: String { get {
        unit.rawValue + ":" + value.description
    }}
}

/// Measurement unit for interpreting the proximity data values.
public enum ProximityMeasurementUnit : String {
    /// Received signal strength indicator, e.g. BLE signal strength as proximity estimator.
    case RSSI
    /// Roundtrip time, e.g. Audio signal echo time duration as proximity estimator.
    case RTT
}


