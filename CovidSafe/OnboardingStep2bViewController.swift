//
//  OnboardingStep2bViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class OnboardingStep2bViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)        
        BluetraceManager.shared.turnOn()
        UserDefaults.standard.set(true, forKey: "turnedOnBluetooth")
    }
    
    @IBAction func learnMoreTapped(_ sender: Any) {
        guard let url = URL(string: "https://www.covidsafe.gov.au/help-topics.html#bluetooth-pairing-request") else {
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    @IBAction func continueBtnTapped(_ sender: UIButton) {
        requestAllPermissions()
    }
    
    func requestAllPermissions() {
        
        UNUserNotificationCenter.current() // 1
            .requestAuthorization(options: [.alert, .sound, .badge]) { // 2
                granted, error in
                
                UserDefaults.standard.set(true, forKey: "allowedPermissions")
                print("Permissions granted: \(granted)") // 3
                
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "showHomeSegue", sender: self)
                }
        }
    }
}
