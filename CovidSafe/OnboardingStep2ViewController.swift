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
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
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
