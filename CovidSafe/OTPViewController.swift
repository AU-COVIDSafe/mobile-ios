//
//  OTPViewController.swift
//  
//
//

import UIKit
import KeychainSwift
import SafariServices

class OTPViewController: UIViewController, RegistrationHandler {

    enum Status {
        case InvalidOTP
        case WrongOTP
        case Success
    }
    
    // MARK: - UI
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var codeInputView: CodeInputView?
    @IBOutlet weak var expiredMessageLabel: UILabel?
    @IBOutlet weak var errorMessageLabel: UILabel?
    
    @IBOutlet weak var wrongNumberButton: UIButton?
    @IBOutlet weak var resendCodeButton: UIButton?
    
    @IBOutlet weak var verifyButton: UIButton?
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // If this view is part of the reauthentiation flow of an expired JWT
    var reauthenticating: Bool = false
    var registrationInfo: RegistrationRequest?
    
    var timer: Timer?
    
    static let fiveMinutes = 300
    
    var countdownSeconds = fiveMinutes
    let verifyEnabledColor = UIColor.covidSafeButtonColor
    let verifyDisabledColor = UIColor(red: 219/255.0, green: 221/255.0, blue: 221.0/255.0, alpha: 1.0)

    let linkButtonAttributes: [NSAttributedString.Key: Any] = [ .foregroundColor: UIColor(red: 53.0/255.0, green: 111.0/255.0, blue: 152.0/255.0, alpha: 1.0), .underlineStyle: NSUnderlineStyle.single.rawValue]
    
    lazy var countdownFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dismissKeyboardOnTap()
        codeInputView?.isOneTimeCode = true

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        var numberWithCountryCode = "Unknown"
        if let regInfo = registrationInfo {
            numberWithCountryCode = "+61 \(regInfo.phoneNumber)"
        }
        self.titleLabel.text = "Enter the PIN sent to \(numberWithCountryCode)"
        startTimer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let _ = codeInputView?.becomeFirstResponder()
    }
    
    func startTimer() {
        countdownSeconds = OTPViewController.fiveMinutes
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(OTPViewController.updateTimerCountdown), userInfo: nil, repeats: true)
        if #available(iOS 13.0, *) {
            expiredMessageLabel?.textColor = .label
        } else {
            expiredMessageLabel?.textColor = .black
        }
        expiredMessageLabel?.isHidden = true
        errorMessageLabel?.isHidden = true
        verifyButton?.isEnabled = false
        verifyButton?.backgroundColor = self.verifyDisabledColor
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc
    func updateTimerCountdown() {
        countdownSeconds -= 1
        
        if countdownSeconds > 0 {
            let countdown = countdownFormatter.string(from: TimeInterval(countdownSeconds))!
            var countdownFormatted = countdown
            if (countdown.range(of: #"\d{2}:"#, options: .regularExpression) != nil) {
                countdownFormatted = String(countdown.suffix(from: countdown.index(after: countdown.startIndex)))
            }
            expiredMessageLabel?.text = "Your PIN will expire in \(countdownFormatted)"
            expiredMessageLabel?.isHidden = false
            if let OTP = codeInputView?.text {
                verifyButton?.isEnabled = OTP.count > 0
                verifyButton?.backgroundColor = OTP.count > 0 ? self.verifyEnabledColor : self.verifyDisabledColor
            }
        } else {
            timer?.invalidate()
            expiredMessageLabel?.text = NSLocalizedString("CodeHasExpired", comment: "Your code has expired.")
            expiredMessageLabel?.textColor = UIColor(0xA31919)
            
            verifyButton?.isEnabled = false
            verifyButton?.backgroundColor = self.verifyDisabledColor
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    private func verifyPhoneNumber(_ phoneNumber: String) {
        guard self.registrationInfo != nil else {
            return
        }
        PhoneValidationAPI.verifyPhoneNumber(regInfo: self.registrationInfo!) {[weak self]  (session, error) in
            if let error = error {
                let errorAlert = UIAlertController(title: "Error verifying phone number", message: "Please try again later.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                    NSLog("Unable to verify phone number")
                }))
                self?.present(errorAlert, animated: true)
                DLog("Phone number verification error: \(error.localizedDescription)")
                return
            }
            UserDefaults.standard.set(session, forKey: "session")
        }
        startTimer()
    }
    
    @IBAction func issuesWithPinTapped(_ sender: UIButton) {
        let pinUrl = URLHelper.getAustralianNumberURL()
        guard let url = URL(string: pinUrl) else {
            DLog("Unable to create url")
            return
        }
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    @IBAction func resendCode(_ sender: UIButton) {
        guard let regInfo = registrationInfo else {
            self.navigationController?.popViewController(animated: true)
            return
        }
        let numberWithCountryCode = "+61 \(regInfo.phoneNumber)"

        let result = PhoneNumberParser.parse(numberWithCountryCode)
        
        switch result {
        case .success(let parsedNumber):
            verifyPhoneNumber(parsedNumber)
            
        case .failure(let error):
            let errorAlert = UIAlertController(title: "Wrong number format", message: "Please enter a mobile phone number", preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                self.navigationController?.popViewController(animated: true)
                NSLog("Unable to verify phone number")
            }))
            present(errorAlert, animated: true)
            DLog("Client side phone number verification error: \(error.localizedDescription)")
            return
        }
    }
    
    func verifyOTP(_ result: @escaping (Status) -> Void) {
        guard let OTP = codeInputView?.text else {
            result(.InvalidOTP)
            return
        }
        
        guard OTP.range(of: "^[0-9]{6}$", options: .regularExpression) != nil else {
            result(.InvalidOTP)
            return
        }
        
        let session = UserDefaults.standard.string(forKey: "session") ?? ""
        RespondToAuthChallengeAPI.respondToAuthChallenge(session: session,
                                                         code: OTP)
        { (token: String?, error: Error?) in
            if let error = error {
                // User was not signed in. Display error.
                DLog(error.localizedDescription)
                result(.WrongOTP)
                return
            }
            guard let tokenToStore = token else {
                result(.WrongOTP)
                return
            }
            let keychain = KeychainSwift()
            keychain.set(tokenToStore, forKey: "JWT_TOKEN")
            result(.Success)
        }
    }
    
    @IBAction func verify(_ sender: UIButton) {
        activityIndicator.startAnimating()
        self.errorMessageLabel?.isHidden = true
        verifyOTP { [unowned viewController = self] status in
            self.activityIndicator.stopAnimating()
            switch status {
            case .InvalidOTP:
                viewController.errorMessageLabel?.text = NSLocalizedString("InvalidOTP", comment: "Must be a 6-digit code")
                self.errorMessageLabel?.isHidden = false
                self.codeInputView?.invalidCode = true
            case .WrongOTP:
                viewController.errorMessageLabel?.text = NSLocalizedString("WrongOTP", comment: "Wrong PIN entered")
                self.errorMessageLabel?.isHidden = false
                self.codeInputView?.invalidCode = true
            case .Success:
                if (self.reauthenticating) {
                    self.dismiss(animated: true, completion: nil)
                    return
                }
                if !UserDefaults.standard.bool(forKey: "allowedPermissions") {
                    viewController.performSegue(withIdentifier: "showAllowPermissionsFromOTPSegue", sender: self)
                } else if !UserDefaults.standard.bool(forKey: "turnedOnBluetooth") {
                    self.performSegue(withIdentifier: "OTPToTurnOnBtSegue", sender: self)
                } else {
                    self.performSegue(withIdentifier: "OTPToHomeSegue", sender: self)
                }
            }
        }
    }
}
