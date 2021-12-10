//
//  RegistrationConsentViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

class RegistrationConsentViewController: UIViewController {
    
    @IBOutlet weak var introLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let attributedString = introLabel.attributedText else {
            return
        }
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        mutableString.parseItalicTags()
        introLabel.attributedText = mutableString
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func onAgreeTapped(sender: UIButton) {
        UserDefaults.standard.set(true, forKey: "hasConsented")
        performSegue(withIdentifier: "iConsentSegue", sender: nil)
    }
}
