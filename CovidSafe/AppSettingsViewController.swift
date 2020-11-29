//
//  AppSettingsViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreBluetooth
import UserNotifications

class AppSettingsViewController: UIViewController {
    private var backupSensorDidUpdateStateCallback: ((SensorState, SensorType?) -> Void)?
    
    @IBOutlet weak var stepCounterLabel: UILabel!
    @IBOutlet weak var topContentTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stepCounterLabel.text = String.localizedStringWithFormat( "stepCounter".localizedString(),
            4,
            4
        )
        topContentTextView.addLink("\(URLHelper.getHelpURL())#location-permission-android", enclosedIn: "*")
        topContentTextView.addAllBold(enclosedIn: "#")
    }
    
    @IBAction func proceedTapped(_ sender: UIButton) {
        self.backupSensorDidUpdateStateCallback = BluetraceManager.shared.sensorDidUpdateStateCallback
        BluetraceManager.shared.sensorDidUpdateStateCallback = sensorManagerDidUpdateBluetoothCallback
        BluetraceManager.shared.turnOnBLE()
        UserDefaults.standard.set(true, forKey: "turnedOnBluetooth")
    }
    
    func sensorManagerDidUpdateBluetoothCallback(_ state: SensorState, type: SensorType?) {
        DLog("Bluetooth state changed in permission request to \(state.rawValue)")
        requestPushPermissions()
    }
    
    func sensorManagerDidUpdateLocationCallback(_ state: SensorState, type: SensorType?) {
        DLog("Location state changed in permission request to \(state.rawValue)")
        
        UserDefaults.standard.set(true, forKey: "allowedPermissions")
        BluetraceManager.shared.sensorDidUpdateStateCallback = self.backupSensorDidUpdateStateCallback
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "showSuccessSegue", sender: self)
        }
    }
    
    func requestPushPermissions() {
        
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) {
                granted, error in
                print("Permissions granted: \(granted)")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    BluetraceManager.shared.sensorDidUpdateStateCallback = self.sensorManagerDidUpdateLocationCallback
                    BluetraceManager.shared.turnOnLocationSensor()
                }
        }
    }
}
