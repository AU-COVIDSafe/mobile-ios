//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

final class FeedbackViewController: UIViewController {
    
    @IBOutlet var issueTextView: UITextView!
    @IBOutlet var issuePlaceholderLabel: UILabel!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var thankYouView: UIView!
    
    private var sendFeebackAction: SendFeedbackAction?
    
    var settings: FeedbackSettings?
    var onDidFinish: (() -> Void)?
    var flowNavBarStyle: UIStatusBarStyle = UIApplication.shared.statusBarStyle
    
    enum State {
        case idle
        case sending
        case sent
    }
    
    private var state: State = .idle {
        didSet {
            updateUI()
        }
    }
    
    private lazy var sendBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "global_send_button_title".localizedString(comment: "Send Button"),
                                   style: .done,
                                   target: self,
                                   action: #selector(sendButtonTapped))
        item.tintColor = .covidSafeColor
        return item
    }()

    private lazy var doneButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Done".localizedString(), style: .done, target: self, action: #selector(doneButtonTapped))
        item.tintColor = .covidSafeColor
        return item
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
        }
        setup()
    }
    
    @objc func cancel() {
        if issueTextView.isFirstResponder {
            issueTextView.resignFirstResponder()
        }
        
        if emailTextField.isFirstResponder {
            emailTextField.resignFirstResponder()
        }
    }
    
    func presentKeyboard() {
        issueTextView.becomeFirstResponder()
    }
    
    private func updateUI() {
        switch state {
        case .idle:
            dismissKeyboard()
            showSendButton()
            issueTextView.isEditable = true
            emailTextField.isEnabled = true
        case .sending:
            showSpinner()
            issueTextView.isEditable = false
            emailTextField.isEnabled = false
        case .sent:
            hideCancelButton()
            showDoneButton()
            showThankYouView()
        }
    }
    
    private func showSendButton() {
        navigationItem.rightBarButtonItem = sendBarButtonItem
    }
    
    private func showSpinner() {
        let activityView = UIActivityIndicatorView(style: .gray)
        activityView.startAnimating()
        let spinnerBarItem = UIBarButtonItem(customView: activityView)
        navigationItem.rightBarButtonItem = spinnerBarItem
    }
    
    private func showDoneButton() {
        navigationItem.rightBarButtonItem = doneButtonItem
    }
    
    private func hideCancelButton() {
        navigationItem.leftBarButtonItem = nil
    }
    
    private func showThankYouView() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.scrollView.isHidden = true
            self?.thankYouView.isHidden = false
        }
    }
    
    private func setup() {
        self.title = "newFeedbackFlow_navigationTitle".localizedString(comment: "Title for feedback flow navigation")
        
        issueTextView.textContainer.lineFragmentPadding = 0.0
        setupDelegates()
        setupKeyboardNotifications()
        setupBarButtonItems()
    }
        
    private func setupDelegates() {
        issueTextView.delegate = self
        emailTextField.addTarget(self, action: #selector(updateSendButton), for: .editingChanged)
    }
    
    private func setupKeyboardNotifications() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func setupBarButtonItems() {
        navigationItem.rightBarButtonItem = sendBarButtonItem
        sendBarButtonItem.isEnabled = false
    }
    
    @objc private func updateSendButton() {
        sendBarButtonItem.isEnabled = !issueTextView.text.isEmpty && !(emailTextField.text?.isEmpty ?? true)
    }
    
    private func updatePlaceholder() {
        issuePlaceholderLabel.isHidden = !issueTextView.text.isEmpty
    }
    
    @objc private func sendButtonTapped(_ sender: Any) {
        guard emailTextField.isValid else {
            let errorMessage = "newFeedback_invalidEmail_errorMessage".localizedString(comment: "Please enter a valid email address!")
            showErrorMessage(errorMessage)
            return
        }
        state = .sending
        send()
    }
    
    @objc private func doneButtonTapped(_ sender: Any) {
        finish()
    }
    
    private func finish() {
        onDidFinish?()
        // Make sure we call the closure only once
        onDidFinish = nil
    }
        
    private func send() {
        guard let settings = settings else {
            assertionFailure("Feedback settings not provided, feedback will be lost")
            state = .idle
            return
        }

        let deviceInfo = UIDevice.current.infoAsDictionary
        let modelName = UIDevice.modelName
        let bundleInfo = Bundle.main.infoAsDictionary

        var customFields = settings.customFields

        if let email = emailTextField.text {
            customFields["E-mail"] = email as AnyObject
        }

        if let osVersion = deviceInfo["systemVersion"] {
            customFields["OS version"] = osVersion
        }

        if let appVersion = bundleInfo["appVersion"] {
            customFields["App version"] = appVersion
        }

        customFields["Phone model"] = modelName as AnyObject

        let issue = Issue(
            feedback: issueTextView.text,
            components: settings.issueComponents,
            type: settings.issueType,
            customFields: customFields,
            reporterUsernameOrEmail: nil
        )
        let action = SendFeedbackAction(issue: issue, screenshotImageOrNil: nil) { outcome in
            switch outcome {
            case .success:
                self.state = .sent
                delayOnMainQueue(2) {
                    self.finish()
                }
                
            case.error:
                self.state = .idle
                let errorMessage = "newFeedback_send_errorMessage".localizedString(comment: "Generic error message shown when feedback could not be sent")

                self.showErrorMessage(errorMessage)
                
            case .cancelled:
                break
            }
        }
        action.start()
        sendFeebackAction = action
    }
    
    private func showErrorMessage(_ message: String) {
        let alert = AlertController(title: "COVIDSafe", message: message, preferredStyle: .alert)
        let okActionTitle = "OK".localizedString()
        let okAction = UIAlertAction(title: okActionTitle, style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        
        if notification.name == UIResponder.keyboardWillHideNotification {
            scrollView.contentInset = .zero
        } else {
            if #available(iOS 11.0, *) {
                scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
            } else {
                scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height, right: 0)
            }
        }
        
        scrollView.scrollIndicatorInsets = scrollView.contentInset
    }
}

func delayOnMainQueue(_ delay: Double, closure:@escaping () -> Void) {
  DispatchQueue.main.asyncAfter(
    deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

extension FeedbackViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        updateSendButton()
    }
}

private extension UITextField {
    var isValid: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: text)
    }
}
