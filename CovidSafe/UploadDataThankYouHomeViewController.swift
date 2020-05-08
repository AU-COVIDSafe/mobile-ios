//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

final class UploadDataThankYouHomeViewController: UIViewController {
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var messageTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMessageTextView()
        navigationController?.setNavigationBarHidden(true, animated: false)
        scrollView.contentInset.top = 44
    }
        
    private func setupMessageTextView() {
        messageTextView.textContainer.lineFragmentPadding = 0.0
    }

    @IBAction func doneBtnTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
}
