//
//  OnboardingStep1aViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import KeychainSwift
import SafariServices

class OnboardingStep1aViewController: UIViewController, UITextViewDelegate {
    
    
    @IBOutlet weak var openLink: UILabel!
    @IBOutlet weak var privacyText: UITextView!
    
    @IBAction func iWantToHelpBtnClick(_ sender: UIButton) {
        UserDefaults.standard.set(true, forKey: "completedIWantToHelp")
        let isLoggedIn: Bool = KeychainSwift().get("JWT_TOKEN") != nil
        if !isLoggedIn {
            self.performSegue(withIdentifier: "personalDetailsSegue", sender: self)
        } else {
            self.performSegue(withIdentifier: "iWantToHelpToConsentSegue", sender: self)
        }
    }

    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func displayFAQ() {
        let nav = HelpNavController()
        nav.modalTransitionStyle = .coverVertical
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if (URL.absoluteString == URLHelper.getHelpURL()) {
            displayFAQ()
        } else {
            let safariVC = SFSafariViewController(url: URL)
            present(safariVC, animated: true, completion: nil)
        }
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let privacyPolicyUrl = URLHelper.getPrivacyPolicyURL()
        privacyText.delegate = self
        privacyText.addLink(privacyPolicyUrl, enclosedIn: "*")
        privacyText.addLink(privacyPolicyUrl, enclosedIn: "*")
        privacyText.addLink(URLHelper.getHelpURL(), enclosedIn: "*")
        privacyText.addLink("https://www.health.gov.au", enclosedIn: "*")
        privacyText.addLink(privacyPolicyUrl, enclosedIn: "*")
    }

}
