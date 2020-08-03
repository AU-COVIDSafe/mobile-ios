//
//  OnboardingStep2ViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import CoreBluetooth
import UserNotifications

class OnboardingStep2ViewController: UIViewController {
    private var bluetoothDidUpdateStateCallback: ((CBManagerState) -> Void)?
    
    @IBOutlet weak var stepCounterLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        stepCounterLabel.text = String.localizedStringWithFormat( "stepCounter".localizedString(),
            4,
            4
        )
    }
    
    @IBAction func proceedTapped(_ sender: UIButton) {
        self.bluetoothDidUpdateStateCallback = BluetraceManager.shared.bluetoothDidUpdateStateCallback
        BluetraceManager.shared.bluetoothDidUpdateStateCallback = centralDidUpdateStateCallback
        BluetraceManager.shared.turnOn()
        UserDefaults.standard.set(true, forKey: "turnedOnBluetooth")
    }
    
    func centralDidUpdateStateCallback(_ state: CBManagerState) {
        DLog("state changed in permission request to \(BluetraceUtils.centralStateToString(state))")
        requestPushPermissions()
    }
    
    func requestPushPermissions() {
        BluetraceManager.shared.bluetoothDidUpdateStateCallback = self.bluetoothDidUpdateStateCallback
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) {
                granted, error in
                
                UserDefaults.standard.set(true, forKey: "allowedPermissions")
                print("Permissions granted: \(granted)")
                
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.performSegue(withIdentifier: "showSuccessSegue", sender: self)
                }
        }
    }
}
