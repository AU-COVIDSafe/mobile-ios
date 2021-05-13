//
//  RegistrationIntroViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices
import KeychainSwift

class RegistrationIntroViewController: UIViewController {
    
    let keychain = KeychainSwift.shared
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        switch UIApplication.shared.isProtectedDataAvailable {
        case true  :
            checkToken()
            break
        case false:
            NotificationCenter.default.addObserver(self, selector: #selector(setKeychainAvailable(_:)), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
            break
        }
    }
    
    @objc
    func setKeychainAvailable(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        checkToken()
    }
    
    func checkToken() {
        let isLoggedIn: Bool = (keychain.get("JWT_TOKEN") != nil)
        
        if isLoggedIn {
            DispatchQueue.main.async {
                let tabVC = MainTabBarViewController()
                self.navigationController?.setViewControllers([tabVC], animated: true)
            }
        }
    }
}
