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
        textView.textContainer.lineFragmentPadding = 0.0
        textView.addLink(URLHelper.getHelpURL(), enclosedIn: "*")
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
