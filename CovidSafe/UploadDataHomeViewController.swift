//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

final class UploadDataHomeViewController: UIViewController {
    
    @IBOutlet var messageTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMessageTextView()
    }
        
    private func setupMessageTextView() {
        messageTextView.textContainer.lineFragmentPadding = 0.0
        messageTextView.addLink("https://www.health.gov.au/using-our-websites/privacy/privacy-notice-for-covidsafe-app", enclosedIn: "*")
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}
