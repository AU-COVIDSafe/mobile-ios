//  Copyright © 2020 Australian Government All rights reserved.
import SafariServices
import UIKit

class PhoneNumberViewController: UIViewController, UITextFieldDelegate, RegistrationHandler {
    
    @IBOutlet weak var phoneNumberField: UITextField!
    @IBOutlet weak var getOTPButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    let PHONE_NUMBER_LENGTH = 17 // e.g. "+61 4 12 345 678 " if text is auto-pasted from text message
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var selectedCountry: String? = "Australia"
    var countryList: [String] = CountriesData.countryArray
    // If this view is part of the reauthentiation flow of an expired JWT
    var reauthenticating: Bool = false
    var registrationInfo: RegistrationRequest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.phoneNumberField.addTarget(self, action: #selector(self.phoneNumberFieldDidChange), for: UIControl.Event.editingChanged)
        self.phoneNumberFieldDidChange()
        phoneNumberField.delegate = self
        dismissKeyboardOnTap()
        if (reauthenticating) {
            self.titleLabel.text = "Enter your mobile number to re-verify"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.phoneNumberField.becomeFirstResponder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func nextButtonClicked(_ sender: Any) {
        parsePhoneNumberAndProceed(self.phoneNumberField.text ?? "")
    }
    
    @IBAction func onAustralianNumberPressed(_ sender: UIButton) {
        guard let url = URL(string: URLHelper.getAustralianNumberURL()) else {
            DLog("Failed to get Aus number URL")
            return
        }
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    @objc
    func phoneNumberFieldDidChange() {
        guard let phoneNumberString = self.phoneNumberField.text else { return }
        if (selectedCountry == "Australia") {
            let result = PhoneNumberParser.parse(phoneNumberString)
            if case .success = result {
                self.phoneNumberField.resignFirstResponder()
            }
        }
    }
    
    func parsePhoneNumberAndProceed(_ number: String) {
        let result = PhoneNumberParser.parse(number)
        
        switch result {
        case .success(let parsedNumber):
            activityIndicator.startAnimating()
            getOTPButton.isEnabled = false
            verifyPhoneNumber(parsedNumber)
            
        case .failure(let error):
            let errorAlert = UIAlertController(title: "Wrong number format", message: "Please enter a mobile phone number", preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                NSLog("Unable to verify phone number")
            }))
            present(errorAlert, animated: true)
            DLog("Client side phone number verification error: \(error.localizedDescription)")
            return
        }
    }
    
    private func verifyPhoneNumber(_ phoneNumber: String) {
        guard self.registrationInfo != nil else {
            return
        }
        self.registrationInfo?.phoneNumber = phoneNumber
        PhoneValidationAPI.verifyPhoneNumber(regInfo: self.registrationInfo!) {[weak self]  (session, error) in
            self?.activityIndicator.stopAnimating()
            self?.getOTPButton.isEnabled = true
            if let error = error {
                let errorAlert = UIAlertController(title: "Error verifying phone number", message: "Please check your details and try again.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                    DLog("Unable to verify phone number")
                }))
                self?.present(errorAlert, animated: true)
                DLog("Phone number verification error: \(error.localizedDescription)")
                return
            }
            UserDefaults.standard.set(session, forKey: "session")
            self?.performSegue(withIdentifier: "segueFromNumberToOTP", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? OTPViewController {
            vc.reauthenticating = self.reauthenticating
            vc.registrationInfo = self.registrationInfo
        }
    }
    
    //  limit text field input to 17 characters
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                           replacementString string: String) -> Bool
    {
        let maxLength = PHONE_NUMBER_LENGTH
        let currentString: NSString = textField.text! as NSString
        let newString: NSString =
            currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
    
    @objc func action() {
       view.endEditing(true)
    }
    
}
