//
//  RegistrationConsentViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

class RegistrationConsentViewController: UIViewController {
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func onAgreeTapped(sender: UIButton) {
        UserDefaults.standard.set(true, forKey: "hasConsented")
        performSegue(withIdentifier: "iConsentSegue", sender: nil)
    }
}
