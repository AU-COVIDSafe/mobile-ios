//
//  ChangePostcodeViewController.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import UIKit
import Lottie

class ChangePostcodeViewController: UIViewController {

    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var postcodeTextField: UITextField!
    @IBOutlet weak var postcodeErrorLabel: UILabel!
    @IBOutlet weak var changePostcodeTextView: UITextView!
    
    var nextBarButtonItem: UIBarButtonItem?
    var initialTextFieldBorderColour: UIColor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.postcodeTextField.delegate = self
        initialTextFieldBorderColour = postcodeTextField.borderColor
        updateContinueButton()
        
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        nextBarButtonItem = UIBarButtonItem(title: "Done".localizedString(),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(self.doneButtonTapped))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([spacer, self.nextBarButtonItem!], animated: true)
        toolBar.isUserInteractionEnabled = true
        postcodeTextField.inputAccessoryView = toolBar
        
        changePostcodeTextView.addLink(URLHelper.getPrivacyPolicyURL(), enclosedIn: "*")
        changePostcodeTextView.addLink(URLHelper.getCollectionNoticeURL(), enclosedIn: "*")
        
    }

    func updateContinueButton() {
        
        if (self.postcodeTextField.text != ""  &&
            self.postcodeErrorLabel.isHidden) {
            
            self.continueButton.isEnabled = true
            self.continueButton.backgroundColor = UIColor.covidSafeButtonDarkerColor
        } else {
            self.continueButton.backgroundColor = UIColor(0xDBDDDD)
            self.continueButton.isEnabled = false
        }
    }
    
    fileprivate func changePostcodeSuccess() {
        
        guard let successVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "registrationSuccess") as? RegistrationSuccessViewController else {
            return
        }
        // force view to load
        _ = successVC.view
        successVC.titleLabel.text = "postcode_success".localizedString()
        navigationController?.pushViewController(successVC, animated: true)
    }
    
    fileprivate func toggleLoadingView() {
        if loadingAnimationView.isHidden {
            continueButton.isHidden = true
            loadingAnimationView.isHidden = false
            startAnimation()
        } else {
            stopAnimation()
            continueButton.isHidden = false
            loadingAnimationView.isHidden = true
        }
    }
    
    fileprivate func setChangePostcodeFailed() {
        postcodeErrorLabel.isHidden = false
        postcodeErrorLabel.text = "postcode_api_error".localizedString()
        postcodeTextField.borderColor = UIColor.covidSafeErrorColor
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: postcodeErrorLabel)
        }
    }
    
    @objc
    func doneButtonTapped() {
        postcodeTextField.resignFirstResponder()
    }

    @IBAction func continueButtonTapped(_ sender: Any) {
        postcodeErrorLabel.isHidden = true
        postcodeTextField.borderColor = initialTextFieldBorderColour
        
        guard let newPostcode = postcodeTextField.text else {
            return
        }
        
        toggleLoadingView()
        
        ChangePostcodeAPI.changePostcode(newPostcode: newPostcode) { (apiError) in
            defer {
                self.toggleLoadingView()
            }
            
            if apiError != nil {
                self.setChangePostcodeFailed()
                return
            }
            
            // if succeeds
            self.changePostcodeSuccess()
        }        
        
    }

    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: Loading animation
    
    @IBOutlet weak var loadingAnimationView: UIView!
    
    var lottieLoadingView: AnimationView?
    
    func startAnimation() {
        if lottieLoadingView == nil {
            let loadingAnimation = AnimationView(name: "Spinner_upload")
            loadingAnimation.loopMode = .loop
            loadingAnimation.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: loadingAnimationView.frame.size)
            loadingAnimationView.addSubview(loadingAnimation)
            lottieLoadingView = loadingAnimation
        }
        lottieLoadingView?.play()
    }
    
    func stopAnimation() {
        lottieLoadingView?.stop()
    }
}

extension ChangePostcodeViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
                
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
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == postcodeTextField {
            if textField.text?.count != 4 {
                postcodeErrorLabel.isHidden = false
                postcodeErrorLabel.text = "personal_details_post_code_error_prompt".localizedString()
                postcodeTextField.borderColor = UIColor.covidSafeErrorColor
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .layoutChanged, argument: postcodeErrorLabel)
                }
            } else {
                postcodeErrorLabel.isHidden = true
                postcodeTextField.borderColor = initialTextFieldBorderColour
            }
        }
        updateContinueButton()
    }
    
}
