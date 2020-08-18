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
        messageTextView.addLink(URLHelper.getPrivacyPolicyURL(), enclosedIn: "*")
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}
