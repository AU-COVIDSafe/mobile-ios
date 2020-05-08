//
//  OnboardingStep4ViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class OnboardingStep4ViewController: UIViewController, SFSafariViewControllerDelegate {
    @IBOutlet var scrollView: UIScrollView?

    @IBAction func consentBtn(_ sender: UIButton) {
        UserDefaults.standard.set(true, forKey: "hasConsented")
    }
    
    @IBAction func privacySafeguardsBtn(_ sender: Any) {
        // check if website exists
        guard let url = URL(string: "https://covidsafe.gov.au/privacy-notice") else {
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
        
        safariVC.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.scrollView?.flashScrollIndicators()
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
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
