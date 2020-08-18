//
//  PersonalDetailsViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class PersonalDetailsViewController: UIViewController, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet weak var firstnameTextField: UITextField!
    @IBOutlet weak var ageTextField: UITextField!
    @IBOutlet weak var postcodeTextField: UITextField!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var scrollview: UIScrollView!
    @IBOutlet weak var dimView: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var fullNameErrorLabel: UILabel!
    @IBOutlet weak var ageErrorLabel: UILabel!
    @IBOutlet weak var postcodeErrorLabel: UILabel!
    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var postcodeLabel: UILabel!
    @IBOutlet weak var enterYourDetailsLabel: UILabel!
    @IBOutlet weak var ageRangeLabel: UILabel!
    @IBOutlet weak var stepCounterLabel: UILabel!
    
    var agePicker: UIPickerView?
    var pickerBarButtonItem: UIBarButtonItem?
    var currentKeyboardFrame: CGRect?
    var nextBarButtonItem: UIBarButtonItem?
    var selectedAge: Int = -1
    let ages = ["0 - 15", "16 - 29", "30 - 39", "40 - 49", "50 - 59", "60 - 69", "70 - 79", "80 - 89", "90+"]
    var initialLabelTextColour: UIColor?
    var initialTextFieldBorderColour: UIColor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.firstnameTextField.delegate = self
        self.ageTextField.delegate = self
        self.agePicker = UIPickerView()
        self.agePicker?.delegate = self
        self.agePicker?.dataSource = self
        self.ageTextField.inputView = self.agePicker
        self.postcodeTextField.delegate = self
        updateContinueButton()
        let toolBar = UIToolbar()
        toolBar.sizeToFit()

        self.nextBarButtonItem = UIBarButtonItem(title: "Done".localizedString(),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(self.nextButtonTapped))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([spacer, self.nextBarButtonItem!], animated: true)
        toolBar.isUserInteractionEnabled = true
        self.postcodeTextField.inputAccessoryView = toolBar
        self.ageTextField.inputAccessoryView = toolBar
        self.firstnameTextField.inputAccessoryView = toolBar
        initialLabelTextColour = fullnameLabel.textColor
        initialTextFieldBorderColour = fullnameLabel.borderColor
        stepCounterLabel.text = String.localizedStringWithFormat( "stepCounter".localizedString(),
            1,
            UserDefaults.standard.bool(forKey: "allowedPermissions") ? 3 : 4
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notif:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(notif:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        if(UIAccessibility.isVoiceOverRunning){
            UIAccessibility.post(notification: .screenChanged, argument: stepCounterLabel)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func nextButtonTapped() {
        guard let focussedField = getCurrentResponder() else {
            return
        }
        switch focussedField {
        case firstnameTextField:
            firstnameTextField.resignFirstResponder()
        case ageTextField:
            postcodeTextField.becomeFirstResponder()
        case postcodeTextField:
            postcodeTextField.resignFirstResponder()
        default:
            return
        }
    }
    
    private func getCurrentResponder() -> UITextField? {
        var currentResponder: UITextField?
        if firstnameTextField.isFirstResponder {
            currentResponder = firstnameTextField
        }
        if ageTextField.isFirstResponder {
            currentResponder = ageTextField
        }
        if postcodeTextField.isFirstResponder {
            currentResponder = postcodeTextField
        }
        
        guard let focussedField = currentResponder else {
            return nil
        }
        return focussedField
    }
    
    func updateScrollviewContentInset() {
        guard let keyboardFrame = currentKeyboardFrame else {
            return
        }
        
        guard let focussedField = getCurrentResponder() else {
            return
        }
        // the reason for the view.frame.height - scrollview.frame.height is because the scrollview is not full height of the view
        // so we don't need to inset the complete keyboard height
        let offsetKeyboardBottom = keyboardFrame.height - (view.frame.height - scrollview.frame.height)
        // 40.0 to give it a little space between the keyboard and the textfield
        let contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: offsetKeyboardBottom + 40, right: 0.0)
        scrollview.contentInset = contentInset
        scrollview.scrollIndicatorInsets = contentInset
        scrollview.scrollRectToVisible(focussedField.frame, animated: true)
    }
    
    @objc
    func keyboardWillHide(notif: Notification) {
        self.currentKeyboardFrame = nil
        let contentInset = UIEdgeInsets.zero
        scrollview.contentInset = contentInset
        scrollview.scrollIndicatorInsets = contentInset
    }
    
    @objc
    func keyboardWillChangeFrame(notif: Notification) {
        let userInfo = notif.userInfo
        guard let keyboardFrame = userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        self.currentKeyboardFrame = keyboardFrame
        updateScrollviewContentInset()
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return ages.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return ages[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedAge = row
        self.ageTextField.text = ages[row]
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (textField == ageTextField) {
            return false
        }
        
        if (string == "") {
            return true
        }

        if (textField == postcodeTextField) {
            let isNumeric = CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
            if (!isNumeric) {
                return false
            }
        }
        if (textField == postcodeTextField && postcodeTextField.text != nil) {
            guard let text = postcodeTextField.text else {
                return false
            }
            let newLength = text.count + string.count - range.length
            return newLength <= 4
        }
        if (textField == firstnameTextField) {
            let invalidChars = CharacterSet(charactersIn: "!?@#$%^&*><:")
            if (string.rangeOfCharacter(from: invalidChars) != nil) {
                return false
            }
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if firstnameTextField == textField {
            firstnameTextField.text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            ageTextField.becomeFirstResponder()
        }
        return false
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if (textField == firstnameTextField || textField == postcodeTextField) {
            nextBarButtonItem?.title = "Done".localizedString()
            if(UIAccessibility.isVoiceOverRunning) {
                firstnameTextField.isAccessibilityElement = true
                postcodeTextField.isAccessibilityElement = true
                backButton.isAccessibilityElement = true
                enterYourDetailsLabel.isAccessibilityElement = true
                fullnameLabel.isAccessibilityElement = true
                ageRangeLabel.isAccessibilityElement = true
                postcodeLabel.isAccessibilityElement = true
                fullNameErrorLabel.isAccessibilityElement = true
                ageErrorLabel.isAccessibilityElement = true
                postcodeErrorLabel.isAccessibilityElement = true
                ageTextField.isAccessibilityElement = true
            }
        } else if (textField == ageTextField) {
            dimView.isHidden = false
            if(UIAccessibility.isVoiceOverRunning) {
                firstnameTextField.isAccessibilityElement = false
                postcodeTextField.isAccessibilityElement = false
                backButton.isAccessibilityElement = false
                enterYourDetailsLabel.isAccessibilityElement = false
                fullnameLabel.isAccessibilityElement = false
                ageRangeLabel.isAccessibilityElement = false
                postcodeLabel.isAccessibilityElement = false
                fullNameErrorLabel.isAccessibilityElement = false
                ageErrorLabel.isAccessibilityElement = false
                postcodeErrorLabel.isAccessibilityElement = false
                ageTextField.isAccessibilityElement = false
                UIAccessibility.post(notification: .screenChanged, argument: agePicker)
            }
            nextBarButtonItem?.title = "Next".localizedString()
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == ageTextField {
            dimView.isHidden = true
            guard let currentRow = agePicker?.selectedRow(inComponent: 0) else {
                updateContinueButton()
                return
            }
            textField.text = ages[currentRow]
            selectedAge = currentRow
        } else if textField == postcodeTextField {
            if textField.text?.count != 4 {
                postcodeErrorLabel.isHidden = false
                postcodeLabel.textColor = UIColor.covidSafeErrorColor
                postcodeTextField.borderColor = UIColor.covidSafeErrorColor
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .layoutChanged, argument: postcodeErrorLabel)
                }
            } else {
                postcodeErrorLabel.isHidden = true
                postcodeLabel.textColor = initialLabelTextColour
                postcodeTextField.borderColor = initialTextFieldBorderColour
            }
        } else if textField == firstnameTextField {
            var hasError = false
            
            
            if textField.text == "" {
                hasError = true
                fullNameErrorLabel.text = "personal_details_name_error_prompt".localizedString()
            }
            else if textField.text?.range(of: #"^[A-Za-z0-9\x{00C0}-\x{017F}][A-Za-z'0-9\-\x{00C0}-\x{017F} ]{0,80}$"#, options: .regularExpression) == nil {
                hasError = true
                fullNameErrorLabel.text = "personal_details_name_characters_prompt".localizedString()
            }
            
            if hasError {
                fullNameErrorLabel.isHidden = false
                fullnameLabel.textColor = UIColor.covidSafeErrorColor
                firstnameTextField.borderColor = UIColor.covidSafeErrorColor
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .layoutChanged, argument: fullNameErrorLabel)
                }
            } else {
                fullNameErrorLabel.isHidden = true
                fullnameLabel.textColor = initialLabelTextColour
                firstnameTextField.borderColor = initialTextFieldBorderColour
            }
        }
        updateContinueButton()
    }
    
    func presentValidationError(error: String, fieldToFocus: UITextField) {
        let errorAlert = UIAlertController(title: "ValidationError".localizedString(comment: "Validation error"),
                                           message: error,
                                           preferredStyle: .alert)
        errorAlert.addAction(UIAlertAction(title: "global_OK".localizedString(),
                                           style: .default,
                                           handler: { _ in
            fieldToFocus.becomeFirstResponder()
        }))
        self.present(errorAlert, animated: true)
    }
    
    func updateContinueButton() {
        firstnameTextField.text = firstnameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (self.ageTextField.text != "" &&
            self.postcodeTextField.text != ""  &&
            self.firstnameTextField.text != "" &&
            self.postcodeErrorLabel.isHidden  &&
            self.fullNameErrorLabel.isHidden) {
            
            self.continueButton.isEnabled = true
            self.continueButton.backgroundColor = UIColor.covidSafeButtonDarkerColor
        } else {
            self.continueButton.backgroundColor = UIColor(0xDBDDDD)
            self.continueButton.isEnabled = false
        }
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }

    
    @IBAction func continueOnTapped(_ sender: Any) {
        let age = ageForSelectedIndex(selectedIndex: selectedAge)
        guard let postCode = postcodeTextField.text else {
            return
        }
        guard postCode.range(of: #"^(0[2|8|9]|[1-9][0-9])\d{2}$"#, options: .regularExpression) != nil else {
            presentValidationError(error: "PostcodeValidationErrorMessage".localizedString(comment: "Please enter a valid postcode"),
                                   fieldToFocus: postcodeTextField)
            return
        }
        
        if(age < 16) {
            performSegue(withIdentifier: "UnderSixteenSegue", sender: self)
        } else {
            performSegue(withIdentifier: "PhoneValidationSegue", sender: self)
        }
    }
    
    func ageForSelectedIndex(selectedIndex: Int) -> Int {
        var age = -1
        switch selectedAge {
        case 0:
            age = 8
        case 1:
            age = 23
        case 2:
            age = 35
        case 3:
            age = 45
        case 4:
            age = 55
        case 5:
            age = 65
        case 6:
            age = 75
        case 7:
            age = 85
        case 8:
            age = 91
        default:
            age = -1
        }
        return age
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let postcode = self.postcodeTextField.text,
            let fullName = self.firstnameTextField.text else {
            return
        }
        let age = ageForSelectedIndex(selectedIndex: selectedAge)
        
        if var vc = segue.destination as? RegistrationHandler {
            let regInfo = RegistrationRequest(fullName: fullName, postcode: postcode, age: age, isMinor: age < 16, phoneNumber: "")
            vc.registrationInfo = regInfo
        }
    }

}
