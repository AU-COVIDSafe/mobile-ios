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

    public var registrationInfo: RegistrationRequest?
    public var reauthenticating: Bool = false
    
    @IBOutlet weak var stepCounterLabel: UILabel!
    @IBOutlet weak var introLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stepCounterLabel.text = String.localizedStringWithFormat( "stepCounter".localizedString(),
            1,
            4
        )
        
        guard let attributedString = introLabel.attributedText else {
            return
        }
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        mutableString.parseItalicTags()
        introLabel.attributedText = mutableString
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if var vc = segue.destination as? RegistrationHandler {
            vc.registrationInfo = self.registrationInfo
        }
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }

    @IBAction func doneOntap(_ sender: Any) {
        performSegue(withIdentifier: "under16Consent", sender: nil)
    }

    @IBAction func dontAgreeTapped(_ sender: Any) {
        let errorAlert = UIAlertController(title: "",
                                           message: "non_consent_popup".localizedString(),
                                           preferredStyle: .alert)
        errorAlert.addAction(UIAlertAction(title: "global_OK".localizedString(), style: .default))
        present(errorAlert, animated: true)
    }
}
