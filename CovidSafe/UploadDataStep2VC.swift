import Foundation
import UIKit
import Lottie
import CoreData
import KeychainSwift

enum UploadResult {
    case Success
    case SessionExpired
    case Failed
    case FailedUpload
    case InvalidCode
}

class UploadDataStep2VC: UIViewController, CodeInputViewDelegate {
    func codeDidChange(codeInputView: CodeInputView) {
        updateUploadButton()
    }
    
    func codeDidFinish(codeInputView: CodeInputView) {
        updateUploadButton()
    }
    
    @IBOutlet weak var codeInputView: CodeInputView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var uploadErrorMsgLbl: UILabel!
    @IBOutlet weak var uploadDataButton: GradientButton!
    @IBOutlet weak var uploadingView: UIView!
    @IBOutlet weak var uploadAnimatedviewContainer: UIView!
    
    var currentKeyboardFrame: CGRect?
    var uploadAnimatedView: AnimationView?
    
    let uploadFailErrMsg = "Upload failed. Please try again later."
    let invalidPinErrMsg = "Invalid PIN, please ask the health official to send you another PIN."
    
    let verifyEnabledColor = UIColor.covidSafeButtonColor
    let verifyDisabledColor = UIColor(red: 219/255.0, green: 221/255.0, blue: 221.0/255.0, alpha: 1.0)

    lazy var countdownFormatter: DateComponentsFormatter = {
           let formatter = DateComponentsFormatter()
           formatter.allowedUnits = [.minute, .second]
           formatter.unitsStyle = .positional
           formatter.zeroFormattingBehavior = .pad
           return formatter
       }()
    
    override func viewDidLoad() {
        _ = codeInputView.becomeFirstResponder()
        codeInputView.delegate = self
        dismissKeyboardOnTap()
        updateUploadButton()
        
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setIsLoading(false)
        
        let uploadAnimation = AnimationView(name: "Spinner_upload")
        uploadAnimation.loopMode = .loop
        uploadAnimation.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: self.uploadAnimatedviewContainer.frame.size)
        self.uploadAnimatedviewContainer.addSubview(uploadAnimation)
        uploadAnimatedView = uploadAnimation
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notif:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(notif:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func keyboardWillHide(notif: Notification) {
        self.currentKeyboardFrame = nil
        let contentInset = UIEdgeInsets.zero
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
    }
    
    @objc
    func keyboardWillChangeFrame(notif: Notification) {
        let userInfo = notif.userInfo
        guard let keyboardFrame = userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        currentKeyboardFrame = keyboardFrame
        updateScrollviewContentInset()
    }
    
    func updateScrollviewContentInset() {
        guard let keyboardFrame = currentKeyboardFrame else {
            return
        }
        // the reason for the view.frame.height - scrollview.frame.height is because the scrollview is not full height of the view
        // so we don't need to inset the complete keyboard height
        let offsetKeyboardBottom = keyboardFrame.height - (view.frame.height - scrollView.frame.height)
        let contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: offsetKeyboardBottom, right: 0.0)
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
        scrollView.scrollRectToVisible(codeInputView.frame, animated: true)
    }
    
    func updateUploadButton() {
        if let OTP = codeInputView?.text {
            uploadDataButton.isEnabled = OTP.count == 6
            uploadDataButton.backgroundColor = OTP.count == 6 ? verifyEnabledColor : verifyDisabledColor
        } else {
            uploadDataButton.isEnabled = false
            uploadDataButton.backgroundColor = verifyDisabledColor
        }
    }

    @IBAction func backBtnTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func uploadDataBtnTapped(_ sender: UIButton) {
        uploadErrorMsgLbl.isHidden = true
        let code = codeInputView.text
        
        guard code.range(of: "^[0-9]{6}$", options: .regularExpression) != nil else {
            uploadErrorMsgLbl.isHidden = false
            uploadErrorMsgLbl.text = invalidPinErrMsg
            return
        }
        
        setIsLoading(true)
        self.codeInputView.invalidCode = false
        UploadHelper.uploadEncounterData(pin: code) { result in
            self.setIsLoading(false)
            switch result{
            case .InvalidCode:
                self.codeInputView.invalidCode = true
                self.uploadErrorMsgLbl.text = self.invalidPinErrMsg
                self.uploadErrorMsgLbl.isHidden = false
            case .Success:
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "uploadDataDate")
                let firstUploadDate = UserDefaults.standard.double(forKey: "firstUploadDataDate")
                if(firstUploadDate == 0){
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "firstUploadDataDate")
                }
                Encounter.deleteAll()
                self.performSegue(withIdentifier: "showSuccessVCSegue", sender: nil)
            case .FailedUpload:
                self.performSegue(withIdentifier: "uploadErrorSegue", sender: self)
                sender.isEnabled = true
            case .Failed:
                 self.performSegue(withIdentifier: "uploadErrorSegue", sender: self)
                sender.isEnabled = true
            case .SessionExpired:
                NotificationCenter.default.post(name: .jwtExpired, object: nil)
                sender.isEnabled = true
            }
        }
    }
    
    func displayUploadDataError() {
        let errorAlert = UIAlertController(title: "Upload failed",
                                           message: "Please try again later.",
                                           preferredStyle: .alert)
        errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(errorAlert, animated: true)
    }
    
    private func setIsLoading(_ isLoading: Bool) {
        if isLoading {
            uploadAnimatedView?.play()
            uploadingView.alpha = 1
            uploadingView.isHidden = false
        } else {
            uploadAnimatedView?.stop()
            uploadingView.alpha = 0
            uploadingView.isHidden = true
        }
    }
}
