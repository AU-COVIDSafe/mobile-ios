//
//  RegistrationConsentViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

class RegistrationConsentViewController: UIViewController {
    
    @IBOutlet weak var consentCheckBox: UIButton!
    @IBOutlet weak var agreeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        agreeButton.isEnabled = false
        consentCheckBox.setImage(UIImage(named: "emptyCheckbox"), for: .normal)
        consentCheckBox.setImage(UIImage(named: "selectedCheckbox"), for: .selected)
        updateContinueButton()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func onCheckboxTapped(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        self.agreeButton.isEnabled = sender.isSelected
        updateContinueButton()
        
        consentCheckBox.accessibilityLabel = sender.isSelected ? "I consent checkbox, checked" : "I consent checkbox, unchecked"
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func onAgreeTapped(sender: UIButton) {
        UserDefaults.standard.set(true, forKey: "hasConsented")
        performSegue(withIdentifier: "iConsentSegue", sender: nil)
    }
    
    func updateContinueButton() {
        if (agreeButton.isEnabled) {
            agreeButton.backgroundColor = UIColor.covidSafeButtonDarkerColor
        } else {
            agreeButton.backgroundColor = UIColor(0xDBDDDD)
        }
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
