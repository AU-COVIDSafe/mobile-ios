//  Copyright © 2020 Australian Government All rights reserved.
import SafariServices
import UIKit
import FlagKit

class PhoneNumberViewController: UIViewController, UITextFieldDelegate, RegistrationHandler, CountrySelectionDelegate {
    
    @IBOutlet weak var phoneNumberField: UITextField!
    @IBOutlet weak var countryCodeField: UITextField!
    @IBOutlet weak var getOTPButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var phoneExample: UILabel!
    @IBOutlet weak var phoneError: UILabel!
    @IBOutlet weak var phoneLabel: UILabel!
    @IBOutlet weak var stepCounterLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    var countryFlagContainerView: UIView!
    var flagImageView: UIImageView!
    
    let PHONE_NUMBER_LENGTH = 17 // e.g. "+61 4 12 345 678 " if text is auto-pasted from text message
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var selectedCountry: Country?
    var countryList: [String] = CountriesData.countryArray
    // If this view is part of the reauthentiation flow of an expired JWT
    var reauthenticating: Bool = false
    var registrationInfo: RegistrationRequest?
    var initialLabelTextColour: UIColor?
    var initialTextFieldBorderColour: UIColor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.phoneNumberField.addTarget(self, action: #selector(self.phoneNumberFieldDidChange), for: UIControl.Event.editingChanged)
        self.phoneNumberFieldDidChange()
        phoneNumberField.delegate = self
        dismissKeyboardOnTap()
        if (reauthenticating) {
            self.titleLabel.text = "EnterPhoneReVerify".localizedString(comment: "Enter your mobile number to re-verify")
        }
        countryCodeField.text = "(+61) " + "country_region_name_au".localizedString()
        countryCodeField.accessibilityValue = String.init(format: "SelectedCountryTemplate".localizedString(), "61", "country_region_name_au".localizedString())
        
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        let nextBarButtonItem = UIBarButtonItem(title: "Done".localizedString(),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(self.dismissKeyboard))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([spacer, nextBarButtonItem], animated: true)
        toolBar.isUserInteractionEnabled = true
        self.phoneNumberField.inputAccessoryView = toolBar
        
        // Set initial Country img
        countryFlagContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        let flag = Flag(countryCode: "AU")!
        let flagImage = flag.originalImage
        flagImageView = UIImageView(frame: CGRect(x: 0, y: 2, width: 28, height: 20))
        flagImageView.contentMode = .scaleAspectFit
        flagImageView.image = flagImage
        countryFlagContainerView.addSubview(flagImageView)
        
        // Set View
        let chevronImg = UIImage(named: "ChevronRight")
        let chevronImgView = UIImageView(frame: CGRect(x: 32, y: 0, width: 24, height: 24))
        if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            // change frame of the chevron and flag
            chevronImgView.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            flagImageView.frame = CGRect(x: 28, y: 2, width: 28, height: 20)
        }
        chevronImgView.image = chevronImg
        countryFlagContainerView.addSubview(chevronImgView)
        
        countryCodeField.rightView = countryFlagContainerView
        countryCodeField.rightViewMode = .always
        countryCodeField.delegate = self
        
        initialLabelTextColour = phoneLabel.textColor
        initialTextFieldBorderColour = phoneNumberField.borderColor
        navigationController?.view.backgroundColor = UIColor.white
        
        if reauthenticating {
            backButton.isHidden = true
            registrationInfo = RegistrationRequest(fullName: "", postcode: "", age: 20, isMinor: false, phoneNumber: "")
            stepCounterLabel.text = String.localizedStringWithFormat( "stepCounter".localizedString(),
                                                                      1,
                                                                      2
            )
        } else {
            stepCounterLabel.text = String.localizedStringWithFormat( "stepCounter".localizedString(),
                                                                      2,
                                                                      UserDefaults.standard.bool(forKey: "allowedPermissions") ? 3 : 4
            )
        }
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func nextButtonClicked(_ sender: Any) {
        parsePhoneNumberAndProceed(self.phoneNumberField.text ?? "")
    }
        
    @objc
    func phoneNumberFieldDidChange() {
        guard let phoneNumberString = self.phoneNumberField.text else { return }
        if (selectedCountry == nil || selectedCountry?.name == "Australia") {
            let result = PhoneNumberParser.parse(phoneNumberString, countryCode: "61")
            if case .success = result {
                self.phoneNumberField.resignFirstResponder()
            }
        }
    }
    
    func parsePhoneNumberAndProceed(_ number: String) {
        let result = PhoneNumberParser.parse(number, countryCode: selectedCountry?.phoneCode ?? "61")
        
        switch result {
        case .success(let parsedNumber):
            activityIndicator.startAnimating()
            getOTPButton.isEnabled = false
            verifyPhoneNumber(parsedNumber)
            
        case .failure(let error):
            let errorAlert = UIAlertController(title: "PhoneNumberFormatErrorTitle".localizedString(),
                                               message: "PhoneNumberFormatErrorMessage".localizedString(),
                                               preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "global_OK".localizedString(), style: .default, handler: { _ in
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
        self.registrationInfo?.countryPhoneCode = selectedCountry?.phoneCode ?? "61"
        PhoneValidationAPI.verifyPhoneNumber(regInfo: self.registrationInfo!) {[weak self]  (session, error) in
            self?.activityIndicator.stopAnimating()
            self?.getOTPButton.isEnabled = true
            if let error = error {
                let errorAlert = UIAlertController(title: "PhoneVerificationErrorTitle".localizedString(),
                                                   message: "PhoneVerificationErrorMessage".localizedString(),
                                                   preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "global_OK".localizedString(), style: .default, handler: { _ in
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
        if let vc = segue.destination as? SelectCountryViewController {
            navigationController?.setNavigationBarHidden(false, animated: false)
            vc.countrySelectionDelegate = self            
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
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == phoneNumberField {
            validatePhoneNumber()
        }
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == countryCodeField {
            phoneNumberField.resignFirstResponder()
            performSegue(withIdentifier: "selectCountrySegue", sender: self)
            return false
        }
        return true
    }
    
    @objc func action() {
       view.endEditing(true)
    }
    
    func setCountry(country: Country) {
        selectedCountry = country
        
        flagImageView.image = selectedCountry?.flag?.originalImage
        guard let countryName = country.name, let countryPhoneCode = country.phoneCode else {
            return
        }
        countryCodeField.text = "(+\(countryPhoneCode)) \(countryName)"
        countryCodeField.accessibilityValue = String.init(format: "SelectedCountryTemplate".localizedString(), countryPhoneCode, countryName)
        if selectedCountry?.isoCode == "AU2" {
            phoneExample.isHidden = false
        } else {
            phoneExample.isHidden = true
        }
        validatePhoneNumber()
    }
    
    func validatePhoneNumber() {
        phoneExample.textColor = initialLabelTextColour
        phoneLabel.textColor = initialLabelTextColour
        phoneNumberField.borderColor = initialTextFieldBorderColour
        phoneError.isHidden = true
        let countryCode = selectedCountry?.phoneCode ?? "61"
        
        guard let phoneText = phoneNumberField.text, phoneText.count > 0 else {
            return
        }
        
        let parseResult = PhoneNumberParser.parse(phoneText, countryCode: countryCode)
        
        switch parseResult {
        case .failure( _):
            phoneError.isHidden = false
            phoneExample.textColor = UIColor.covidSafeErrorColor
            phoneLabel.textColor = UIColor.covidSafeErrorColor
            phoneNumberField.borderColor = UIColor.covidSafeErrorColor
            if selectedCountry == nil || selectedCountry?.isoCode == "AU" {
                phoneError.text = "invalid_australian_phone_number_error_prompt".localizedString()
            } else if selectedCountry?.isoCode == "AU2" {
                phoneError.text = "invalid_norfolk_island_phone_number_error_prompt".localizedString()
            }
            
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .layoutChanged, argument: phoneError)
            }
            break
        default:
            break
        }
        
    }
}

protocol CountrySelectionDelegate {
    func setCountry(country: Country)
}
