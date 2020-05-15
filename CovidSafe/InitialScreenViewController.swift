//
//  InitialScreenViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import KeychainSwift

class InitialScreenViewController: UIViewController {
    
    let displayTimeSeconds: Int = 4
    let giveupTimeSeconds = 8.0
    var isKeychainAvailable = false
    var isDisplayTimeElapsed = false
    let keychain = KeychainSwift()
    var giveupTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch UIApplication.shared.isProtectedDataAvailable {
        case true  :
            isKeychainAvailable = true
            break
        case false:
            NotificationCenter.default.addObserver(self, selector: #selector(setKeychainAvailable(_:)), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
            break
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.window?.tintColor = .covidSafeColor
        
        let showAppDelay = DispatchTime.now() + .seconds(displayTimeSeconds)
        DispatchQueue.main.asyncAfter(deadline: showAppDelay, execute: {
            self.isDisplayTimeElapsed = true
            if(self.proceedWithChecks()) {
                self.performCheck()
            }
        })
        // add give up action in case the keychain notification in not received after 8 seconds
        giveupTimer = Timer.scheduledTimer(withTimeInterval: giveupTimeSeconds, repeats: false) { timer in
            self.performSegue(withIdentifier: "initialPersonalDetailsSegue", sender: self)
        }
    }
    
    @objc
    func setKeychainAvailable(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        isKeychainAvailable = true
        if(self.proceedWithChecks()) {
            self.performCheck()
        }
    }
    
    private func proceedWithChecks() -> Bool {
        return isDisplayTimeElapsed && isKeychainAvailable
    }
    
    private func performCheck() {
        giveupTimer?.invalidate()
        let isLoggedIn: Bool = (keychain.get("JWT_TOKEN") != nil)
        if !UserDefaults.standard.bool(forKey: "completedIWantToHelp") {
                // old app signed out here
            keychain.delete("JWT_TOKEN")
            self.performSegue(withIdentifier: "initialScreenToIWantToHelpSegue", sender: self)
        } else if !UserDefaults.standard.bool(forKey: "hasConsented") {
            self.performSegue(withIdentifier: "initialScreenToConsentSegue", sender: self)
        } else if !isLoggedIn {
            self.performSegue(withIdentifier: "initialPersonalDetailsSegue", sender: self)
        } else if !UserDefaults.standard.bool(forKey: "allowedPermissions") {
            self.performSegue(withIdentifier: "initialScreenToAllowPermissionsSegue", sender: self)
        } else if !UserDefaults.standard.bool(forKey: "turnedOnBluetooth") {
            self.performSegue(withIdentifier: "initialScreenToTurnOnBtSegue", sender: self)
        } else {
            self.performSegue(withIdentifier: "initialScreenToHomeSegue", sender: self)
        }
    }
}
