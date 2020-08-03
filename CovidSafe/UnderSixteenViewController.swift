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
    @IBOutlet weak var stepCounterLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stepCounterLabel.text = String.localizedStringWithFormat( "stepCounter".localizedString(),
            1,
            4
        )
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

}
