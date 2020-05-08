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
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.window?.tintColor = .covidSafeColor
        let showAppDelay = DispatchTime.now() + .seconds(displayTimeSeconds)
        DispatchQueue.main.asyncAfter(deadline: showAppDelay, execute: {
            self.performCheck()
        })
    }
    
    private func performCheck() {
        let keychain = KeychainSwift()
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
