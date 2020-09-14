//
//  OnboardingStep1bViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

class OnboardingStep1bViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.textContainer.lineFragmentPadding = 0.0
        textView.addLink(URLHelper.getHelpURL(), enclosedIn: "*")
    }
}
