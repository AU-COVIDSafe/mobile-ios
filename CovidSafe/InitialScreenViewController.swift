//
//  InitialScreenViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import KeychainSwift

class InitialScreenViewController: UIViewController, EncounterDBMigrationProgress {
    
    let displayTimeSeconds = 4.0
    let giveupTimeSeconds = 8.0
    var migrationStart: Date?
    var isKeychainAvailable = false
    var isDisplayTimeElapsed = false
    let keychain = KeychainSwift()
    var giveupTimer: Timer?
    var initialDelayTimer: Timer?
    var migrationViewController: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        EncounterDB.shared.setup(migrationDelegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        switch UIApplication.shared.isProtectedDataAvailable {
        case true  :
            isKeychainAvailable = true
            break
        case false:
            NotificationCenter.default.addObserver(self, selector: #selector(setKeychainAvailable(_:)), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
            break
        }
        
        view.window?.tintColor = .covidSafeColor
        
        // if a migration started let the migration delegate handle the timers
        if migrationStart == nil {
            continueAfterDelay(delay: displayTimeSeconds)
            // add give up action in case the keychain notification in not received after 8 seconds
            giveupTimer = Timer.scheduledTimer(withTimeInterval: giveupTimeSeconds, repeats: false) { timer in
                self.performSegue(withIdentifier: "initialScreenToIWantToHelpSegue", sender: self)
            }
        }
    }
    
    func continueAfterDelay(delay: TimeInterval) {
        initialDelayTimer = Timer.scheduledTimer(withTimeInterval: delay,
                                                 repeats: false,
                                                 block: { (_) in
                                                    self.isDisplayTimeElapsed = true
                                                    if(self.proceedWithChecks()) {
                                                        self.performCheck()
                                                    }
        })
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
        initialDelayTimer?.invalidate()
        if let migrationVc = migrationViewController {
            migrationVc.dismiss(animated: true, completion: nil)
        }
        let isLoggedIn: Bool = (keychain.get("JWT_TOKEN") != nil)
        if !UserDefaults.standard.bool(forKey: "completedIWantToHelp") ||
            !UserDefaults.standard.bool(forKey: "hasConsented") ||
            !isLoggedIn {
            keychain.delete("JWT_TOKEN")
            self.performSegue(withIdentifier: "initialScreenToIWantToHelpSegue", sender: self)
        } else if !UserDefaults.standard.bool(forKey: "allowedPermissions") {
            self.performSegue(withIdentifier: "initialScreenToAllowPermissionsSegue", sender: self)
        } else {
            
            DispatchQueue.main.async {
                let homeVC = HomeViewController(nibName: "HomeView", bundle: nil)
                homeVC.modalPresentationStyle = .overFullScreen
                homeVC.modalTransitionStyle = .coverVertical
                self.present(homeVC, animated: true, completion: nil)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "presentMigrationSegue" {
            migrationViewController = segue.destination
        }
    }
    
    func migrationBegun() {
        DLog("MIGRATION BEGUN")
        giveupTimer?.invalidate()
        initialDelayTimer?.invalidate()
        migrationStart = Date()
        performSegue(withIdentifier: "presentMigrationSegue", sender: nil)
    }
    
    func migrationComplete() {
        DLog("MIGRATION COMPLETE")
        if let migrationStart = migrationStart {
            let migrationDuration = abs(migrationStart.timeIntervalSinceNow)
            if migrationDuration > displayTimeSeconds {
                performCheck()
            } else {
                // migration was quick, still need to delay minimum 4 seconds
                DLog("Migration too quick, waiting \(displayTimeSeconds - migrationDuration) seconds")
                continueAfterDelay(delay: displayTimeSeconds - migrationDuration)
            }
        }
    }
    
    func migrationFailed(error: Error) {
        fatalError("Migration Failed \(error)")
    }
}
