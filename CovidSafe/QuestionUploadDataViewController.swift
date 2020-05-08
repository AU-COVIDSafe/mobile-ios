//  Copyright © 2020 Australian Government All rights reserved.

import Foundation
import UIKit
import KeychainSwift

class QuestionUploadDataViewController: UIViewController {
    
    @IBOutlet var uploadButton: UIButton!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    @IBAction func didTapUpload(_ sender: Any) {
        showUploadDataFlow()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setIsLoading(false)
    }
    
    // MARK: -
    
    private func showUploadDataFlow() {
        let keychain = KeychainSwift()
        setIsLoading(true)
        guard let jwt = keychain.get("JWT_TOKEN") else {
            DLog("Error trying to upload when not logged in")
            setIsLoading(false)
            return
        }
        InitiateUploadAPI.requestUploadOTP(session: jwt) { (success, error) in
            self.setIsLoading(false)
            guard success == true else {
                if let error = error, error == .ExpireSession {
                    NotificationCenter.default.post(name: .jwtExpired, object: nil)
                    return
                }
                DLog("error getting upload OTP \(String(describing: error))")
                self.displayUploadDataError()
                return
            }
            self.performSegue(withIdentifier: "showUploadDataFlow", sender: nil)
        }
    }
    
    func displayUploadDataError() {
        let errorAlert = UIAlertController(title: "Upload request failed",
                                           message: "Please try again later.",
                                           preferredStyle: .alert)
        errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(errorAlert, animated: true)
    }
    
    private func setIsLoading(_ isLoading: Bool) {
        if isLoading {
            uploadButton.alpha = 0.2
            uploadButton.isEnabled = false
            activityIndicator.startAnimating()
        } else {
            uploadButton.alpha = 1
            uploadButton.isEnabled = true
            activityIndicator.stopAnimating()
        }
    }
    
}
