//
//  Sensor.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Sensor for detecting and tracking various kinds of disease transmission vectors, e.g. contact with people, time at location.
public protocol Sensor {
    /// Add delegate for responding to sensor events.
    func add(delegate: SensorDelegate)
    
    /// Start sensing.
    func start()
    
    /// Stop sensing.
    func stop()
}

