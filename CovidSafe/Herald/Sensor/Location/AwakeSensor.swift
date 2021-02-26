//
//  AwakeSensor.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import CoreLocation

protocol AwakeSensor : Sensor {
}

/**
 Screen awake sensor based on CoreLocation. Does NOT make use of the GPS position
 Requires : Signing & Capabilities : BackgroundModes : LocationUpdates = YES
 Requires : Info.plist : Privacy - Location When In Use Usage Description
 Requires : Info.plist : Privacy - Location Always and When In Use Usage Description
 */
class ConcreteAwakeSensor : NSObject, AwakeSensor, CLLocationManagerDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "ConcreteAwakeSensor")
    private var delegates: [SensorDelegate] = []
    private let locationManager = CLLocationManager()
    private let rangeForBeacon: UUID?

    init(desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers, distanceFilter: CLLocationDistance = CLLocationDistanceMax, rangeForBeacon: UUID? = nil) {
        logger.debug("init(desiredAccuracy=\(desiredAccuracy == kCLLocationAccuracyThreeKilometers ? "3km" : desiredAccuracy.description),distanceFilter=\(distanceFilter == CLLocationDistanceMax ? "max" : distanceFilter.description),rangeForBeacon=\(rangeForBeacon == nil ? "disabled" : rangeForBeacon!.description))")
        self.rangeForBeacon = rangeForBeacon
        super.init()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        locationManager.allowsBackgroundLocationUpdates = true
        if #available(iOS 11.0, *) {
            logger.debug("init(ios>=11.0)")
            locationManager.showsBackgroundLocationIndicator = false
        } else {
            logger.debug("init(ios<11.0)")
        }
    }
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func start() {
        logger.debug("start")
        locationManager.startUpdatingLocation()
        logger.debug("startUpdatingLocation")

        // Start beacon ranging
        guard let beaconUUID = rangeForBeacon else {
            return
        }
        if #available(iOS 13.0, *) {
            locationManager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: beaconUUID))
            logger.debug("startRangingBeacons(ios>=13.0,beaconUUID=\(beaconUUID.description))")
        } else {
            let beaconRegion = CLBeaconRegion(proximityUUID: beaconUUID, identifier: beaconUUID.uuidString)
            locationManager.startRangingBeacons(in: beaconRegion)
            logger.debug("startRangingBeacons(ios<13.0,beaconUUID=\(beaconUUID.uuidString)))")
        }
        delegates.forEach({ $0.sensor(.AWAKE, didUpdateState: .on) })
    }
    
    func stop() {
        logger.debug("stop")
        locationManager.stopUpdatingLocation()
        logger.debug("stopUpdatingLocation")
        // Start beacon ranging
        guard let beaconUUID = rangeForBeacon else {
            return
        }
        if #available(iOS 13.0, *) {
            locationManager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: beaconUUID))
            logger.debug("stopRangingBeacons(ios>=13.0,beaconUUID=\(beaconUUID.description))")
        } else {
            let beaconRegion = CLBeaconRegion(proximityUUID: beaconUUID, identifier: beaconUUID.uuidString)
            locationManager.stopRangingBeacons(in: beaconRegion)
            logger.debug("stopRangingBeacons(ios<13.0,beaconUUID=\(beaconUUID.description))")
        }
        delegates.forEach({ $0.sensor(.AWAKE, didUpdateState: .off) })
    }
    
    // MARK:- CLLocationManagerDelegate    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        var state = SensorState.off
        
        if status == CLAuthorizationStatus.authorizedWhenInUse ||
            status == CLAuthorizationStatus.authorizedAlways {
            state = .on
        }
        if status == CLAuthorizationStatus.notDetermined {
            locationManager.requestAlwaysAuthorization()
            locationManager.stopUpdatingLocation()
            locationManager.startUpdatingLocation()
        }
        if status != CLAuthorizationStatus.notDetermined {
            delegates.forEach({ $0.sensor(.AWAKE, didUpdateState: state) })
        }
    }

    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        var state = SensorState.off
        if manager.authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse ||
            manager.authorizationStatus == CLAuthorizationStatus.authorizedAlways {
            state = .on
        }
        if manager.authorizationStatus == CLAuthorizationStatus.notDetermined {
            locationManager.requestAlwaysAuthorization()
            locationManager.stopUpdatingLocation()
            locationManager.startUpdatingLocation()
        }
        if manager.authorizationStatus != CLAuthorizationStatus.notDetermined {
            delegates.forEach({ $0.sensor(.AWAKE, didUpdateState: state) })
        }
    }
    
}
