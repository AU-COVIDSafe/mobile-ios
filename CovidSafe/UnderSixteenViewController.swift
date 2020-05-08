//
//  IsolationSuccessViewController.swift
//  CovidSafe
//
//  Created on 20/4/20.
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class UnderSixteenViewController: UIViewController, RegistrationHandler {

    @IBOutlet weak var consentCheckBox: UIButton!
    @IBOutlet weak var agreeButton: UIButton!
    public var registrationInfo: RegistrationRequest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        consentCheckBox.setImage(UIImage(named: "emptyCheckbox"), for: .normal)
        consentCheckBox.setImage(UIImage(named: "selectedCheckbox"), for: .selected)
        updateContinueButton()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if var vc = segue.destination as? RegistrationHandler {
            vc.registrationInfo = self.registrationInfo
        }
    }
    
    func updateContinueButton() {
        if (agreeButton.isEnabled) {
            agreeButton.backgroundColor = UIColor.covidSafeButtonColor
        } else {
            agreeButton.backgroundColor = UIColor(0xDBDDDD)
        }
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func onCheckboxTapped(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        self.agreeButton.isEnabled = sender.isSelected
        updateContinueButton()
    }

    @IBAction func doneOntap(_ sender: Any) {
        performSegue(withIdentifier: "under16Consent", sender: nil)
    }

}
