//  Copyright © 2020 Australian Government All rights reserved.

import Foundation
import UIKit

class Question3ErrorViewController: UIViewController {

    @IBOutlet var titleTextView: UITextView!
    @IBOutlet var messageTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
        setupTextViews()
    }
    
    private func setupTextViews() {
        titleTextView.textContainer.lineFragmentPadding = 0.0
        titleTextView.addLink("https://aus.gov.au", enclosedIn: "*")
        
        messageTextView.textContainer.lineFragmentPadding = 0.0
        messageTextView.addLink("https://aus.gov.au", enclosedIn: "*")
    }
    
    @IBAction func continueButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
