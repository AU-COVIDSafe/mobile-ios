//
//  OnboardingStep2cViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

class OnboardingStep2cViewController: UIViewController {

    @IBAction func enabledBluetoothBtn(_ sender: UIButton) {
        UserDefaults.standard.set(true, forKey: "turnedOnBluetooth")

        DispatchQueue.main.async {
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { [weak self] settings in
                DispatchQueue.main.async {
                    if settings.authorizationStatus == .authorized && BluetraceManager.shared.isBluetoothAuthorized() && BluetraceManager.shared.isBluetoothOn() {
                        self?.performSegue(withIdentifier: "showFullySetUpFromTurnOnBtSegue", sender: self)
                    } else {
                        self?.performSegue(withIdentifier: "showHomeFromTurnOnBtSegue", sender: self)
                    }
                }
            })
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */

}
