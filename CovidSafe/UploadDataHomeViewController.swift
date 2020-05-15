//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

final class UploadDataHomeViewController: UIViewController {
    
    @IBOutlet var messageTextView: UITextView!
    @IBOutlet weak var consentCheckBox: UIButton!
    @IBOutlet weak var agreeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        consentCheckBox.setImage(UIImage(named: "emptyCheckbox"), for: .normal)
        consentCheckBox.setImage(UIImage(named: "selectedCheckbox"), for: .selected)
        setupMessageTextView()
        updateContinueButton()
    }
        
    private func setupMessageTextView() {
        messageTextView.textContainer.lineFragmentPadding = 0.0
        messageTextView.addLink("https://www.health.gov.au/using-our-websites/privacy/privacy-notice-for-covidsafe-app", enclosedIn: "*")
    }
    
    @IBAction func onCheckboxTapped(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        self.agreeButton.isEnabled = sender.isSelected
        updateContinueButton()
        consentCheckBox.accessibilityLabel = sender.isSelected ? "I consent checkbox, checked" : "I consent checkbox, unchecked"
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    func updateContinueButton() {
        if (agreeButton.isEnabled) {
            agreeButton.backgroundColor = UIColor.covidSafeButtonDarkerColor
        } else {
            agreeButton.backgroundColor = UIColor(0xDBDDDD)
        }
    }
}
