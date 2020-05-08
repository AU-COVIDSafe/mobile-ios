//  Copyright © 2020 Australian Government All rights reserved.

import Foundation
import UIKit

class Question2ErrorViewController: UIViewController {

    @IBOutlet weak var messageTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
        
        messageTextView.textContainer.lineFragmentPadding = 0.0
        messageTextView.addLink("https://www.health.gov.au/news/health-alerts/novel-coronavirus-2019-ncov-health-alert/how-to-protect-yourself-and-others-from-coronavirus-covid-19/self-isolation-self-quarantine-for-coronavirus-covid-19", enclosedIn: "*")
    }
    
    @IBAction func continueButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
