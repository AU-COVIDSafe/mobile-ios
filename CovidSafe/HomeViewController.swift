import UIKit
import Lottie
import KeychainSwift
import SafariServices

class HomeViewController: UIViewController {
    private var observer: NSObjectProtocol?
    
    let animatedHeaderActiveHeightConstant: CGFloat = 160
    let animatedHeaderInactiveHeightConstant: CGFloat = 80
    let animatedHeaderActiveVerticalMarginConstant: CGFloat = 60
    let animatedHeaderInactiveVerticalMarginConstant: CGFloat = 24
    
    @IBOutlet weak var screenStack: UIStackView!
    @IBOutlet weak var bluetoothStatusOffView: UIView!
    @IBOutlet weak var bluetoothStatusOnView: UIView!
    @IBOutlet weak var bluetoothPermissionOffView: UIView!
    @IBOutlet weak var bluetoothPermissionOnView: UIView!
    @IBOutlet weak var homeHeaderView: UIView!
    @IBOutlet weak var homeHeaderInfoText: UILabel!
    @IBOutlet weak var homeHeaderPermissionsOffImage: UIImageView!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var appPermissionsLabel: UIView!
    @IBOutlet weak var animatedBluetoothHeader: UIView!
    @IBOutlet weak var versionNumberLabel: UILabel!
    @IBOutlet weak var versionView: UIView!
    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var helpButton: UIButton!
    @IBOutlet weak var seeOurFAQ: UIButton!
    @IBOutlet weak var pushNotificationStatusTitle: UILabel!
    @IBOutlet weak var pushNotificationStatusIcon: UIImageView!
    @IBOutlet weak var pushNotificationStatusLabel: UILabel!
    @IBOutlet weak var pushNotificationContainerView: UIView!
    @IBOutlet weak var uploadDateLabel: UILabel!
    @IBOutlet weak var pairingRequestsLabel: UILabel!
    @IBOutlet weak var topLeftIcon: UIImageView!
    @IBOutlet weak var animatedBluetoothHeaderHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var animatedBluetoothHeaderTopMarginConstraint: NSLayoutConstraint!
    @IBOutlet weak var animatedBluetoothHeaderBottomMarginConstraint: NSLayoutConstraint!
    
    var lottieBluetoothView: AnimationView!

    var allPermissionOn = true
    var bluetoothStatusOn = true
    var bluetoothPermissionOn = true
    var pushNotificationOn = true
    var didUploadData: Bool {
        let uploadTimestamp = UserDefaults.standard.double(forKey: "uploadDataDate")
        let lastUpload = Date(timeIntervalSince1970: uploadTimestamp)
        return Date().timeIntervalSince(lastUpload) < 86400 * 14
    }
    var dataUploadedAttributedString: NSAttributedString? {
        let uploadTimestamp = UserDefaults.standard.double(forKey: "uploadDataDate")
        if(uploadTimestamp > 0){
            let lastUpload = Date(timeIntervalSince1970: uploadTimestamp)
            let dateFormatterPrint = DateFormatter()
            dateFormatterPrint.dateFormat = "dd MMM yyyy"
            let formattedDate = dateFormatterPrint.string(from: lastUpload)
            let newAttributedString = NSMutableAttributedString(
                string: String.localizedStringWithFormat(
                    "InformationUploaded".localizedString(comment: "Information uploaded template"),
                    formattedDate)
            )

            guard let dateRange = newAttributedString.string.range(of: formattedDate) else { return nil }
            let nsRange = NSRange(dateRange, in: newAttributedString.string)
            newAttributedString.addAttribute(.font,
                                            value: UIFont.boldSystemFont(ofSize: 18),
                                     range: nsRange)
            return newAttributedString
        }
        return nil
    }
    var shouldShowUploadDate: Bool {
        let uploadTimestamp = UserDefaults.standard.double(forKey: "uploadDataDate")
        if(uploadTimestamp > 0){
            let lastUpload = Date(timeIntervalSince1970: uploadTimestamp)
            return Date().timeIntervalSince(lastUpload) <= 86400 * 14
        }
        return false
    }
    
    var _preferredScreenEdgesDeferringSystemGestures: UIRectEdge = []
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return _preferredScreenEdgesDeferringSystemGestures
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // this is to show the settings prompt initially if bluetooth is off
        if !BluetraceManager.shared.isBluetoothOn() {
            BluetraceManager.shared.turnOn()
        }
        
        observer = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [unowned self] notification in
            self.toggleViews()
        }
        
        updateAnimationViewWithAnimationName(name: "Spinner_home")
        
        NotificationCenter.default.addObserver(self, selector: #selector(enableDeferringSystemGestures(_:)), name: .enableDeferringSystemGestures, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableDeferringSystemGestures(_:)), name: .disableDeferringSystemGestures, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableUserInteraction(_:)), name: .disableUserInteraction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enableUserInteraction(_:)), name: .enableUserInteraction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        if let versionNumber = Bundle.main.versionShort, let buildNumber = Bundle.main.version {
            self.versionNumberLabel.text = String.localizedStringWithFormat(
                "home_version_number_ios".localizedString(comment: "Version number template"),
                versionNumber,buildNumber
            )
        } else {
            toggleViewVisibility(view: versionView, isVisible: false)
        }
        
        // Some translators are adding the ** for this link, just cleaning that up.
        let pairingRequestString = NSLocalizedString("PairingRequestsInfo", comment: "Text explaining COVIDSafe does not send pairing requests").replacingOccurrences(of: "*", with: "")
        let pairingRequestText = NSMutableAttributedString(string: pairingRequestString,
                                                           attributes: [.font: UIFont.preferredFont(forTextStyle: .body)])
        let pairingRequestUnderlinedString = NSLocalizedString("PairingRequestsInfoUnderline", comment: "section of text that should be underlined from the PairingRequestsInfo text")
        if let requestsRange = pairingRequestText.string.range(of: pairingRequestUnderlinedString) {
            let nsRange = NSRange(requestsRange, in: pairingRequestText.string)
            pairingRequestText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            pairingRequestsLabel.attributedText = pairingRequestText
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.toggleViews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.lottieBluetoothView?.play()
        self.becomeFirstResponder()
        self.updateJWTKeychainAccess()
        getMessagesFromServer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.lottieBluetoothView?.stop()
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        #if DEBUG
            guard let allowDebug = PlistHelper.getBoolFromInfoPlist(withKey: "Allow_Debug", plistName: "CovidSafe-config") else {
                return
            }
            if allowDebug == true && event?.subtype == .motionShake {
                guard let debugVC = UIStoryboard(name: "Debug", bundle: nil).instantiateInitialViewController() else {
                    return
                }
                debugVC.modalTransitionStyle = .coverVertical
                debugVC.modalPresentationStyle = .fullScreen
                present(debugVC, animated: true, completion: nil)
            }
        #endif
    }
    
    func updateJWTKeychainAccess() {
        let hasUpdatedKeychainAccess = UserDefaults.standard.bool(forKey: "HasUpdatedKeychainAccess")
        if (!hasUpdatedKeychainAccess) {
            let keychain = KeychainSwift()
            if let jwt = keychain.get("JWT_TOKEN") {
                if (keychain.set(jwt, forKey: "JWT_TOKEN", withAccess: .accessibleAfterFirstUnlock)) {
                    DLog("Updated access class on JWT")
                    UserDefaults.standard.set(true, forKey: "HasUpdatedKeychainAccess")
                }
            }
        }
    }
        
    func getMessagesFromServer() {
        MessageAPI.getMessagesIfNeeded() { (messageResponse, error) in
            if let error = error {
                DLog("Get messages error: \(error.localizedDescription)")
            }
            // We currently dont do anything with the response. Messages are delivered via APN
        }
    }
    
    fileprivate func toggleViews() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { [weak self] settings in
                DispatchQueue.main.async {
                    self?.readPermissions(notificationSettings: settings)
                    
                    self?.togglePushNotificationsStatusView()
                    self?.toggleBluetoothStatusView()
                    self?.toggleBluetoothPermissionStatusView()
                    self?.toggleHeaderView()
                    self?.toggleUploadView()
                    self?.toggleUploadDateView()
                }
            })
        }
    }
    
    fileprivate func toggleUploadDateView() {
        if shouldShowUploadDate, let lastUploadText = self.dataUploadedAttributedString {
            uploadDateLabel.attributedText = lastUploadText
            uploadDateLabel.isHidden = false
        } else {
            uploadDateLabel.isHidden = true
        }
    }
    
    fileprivate func readPermissions(notificationSettings: UNNotificationSettings) {
        self.bluetoothStatusOn = BluetraceManager.shared.isBluetoothOn()
        self.bluetoothPermissionOn = BluetraceManager.shared.isBluetoothAuthorized()
        self.pushNotificationOn = notificationSettings.authorizationStatus == .authorized
        self.allPermissionOn = self.bluetoothStatusOn && self.bluetoothPermissionOn
    }
    
    fileprivate func toggleViewVisibility(view: UIView, isVisible: Bool) {
        view.isHidden = !isVisible
    }
    
    func updateAnimationViewWithAnimationName(name: String) {
        let bluetoothAnimation = AnimationView(name: name)
        bluetoothAnimation.loopMode = .loop
        bluetoothAnimation.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: self.animatedBluetoothHeader.frame.size)
        if lottieBluetoothView != nil {
            lottieBluetoothView.stop()
            lottieBluetoothView.removeFromSuperview()
        }
        self.animatedBluetoothHeader.addSubview(bluetoothAnimation)
        lottieBluetoothView = bluetoothAnimation
        lottieBluetoothView.play()
    }
    
    fileprivate func toggleUploadView() {
        toggleViewVisibility(view: self.uploadView, isVisible: !self.didUploadData)
    }
    
    fileprivate func toggleHeaderView() {
        self.allPermissionOn ? self.lottieBluetoothView?.play() : self.lottieBluetoothView?.stop()
        toggleViewVisibility(view: appPermissionsLabel, isVisible: !self.allPermissionOn)
        toggleViewVisibility(view: homeHeaderPermissionsOffImage, isVisible: !self.allPermissionOn)
        toggleViewVisibility(view: lottieBluetoothView, isVisible: self.allPermissionOn)

        var newAttributedLabel = NSMutableAttributedString(string: "home_header_active_title".localizedString(comment: "Header with no action req"), attributes: [.font: UIFont.preferredFont(for: .title1, weight: .bold)])
        newAttributedLabel.append(NSAttributedString(string: "\n" + "home_header_active_no_action_required".localizedString(), attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]))
        
        self.homeHeaderInfoText.attributedText = newAttributedLabel
        
        if (!self.allPermissionOn) {
            newAttributedLabel = NSMutableAttributedString(string: "home_header_inactive_title".localizedString(comment: "Header with no action req"), attributes: [.font: UIFont.preferredFont(for: .title1, weight: .bold)])
            newAttributedLabel.append(NSAttributedString(string: "\n" + "home_header_inactive_check_your_permissions".localizedString(), attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]))
            
            animatedBluetoothHeaderHeightConstraint.constant = animatedHeaderInactiveHeightConstant
            animatedBluetoothHeaderTopMarginConstraint.constant = animatedHeaderInactiveVerticalMarginConstant
            animatedBluetoothHeaderBottomMarginConstraint.constant = animatedHeaderInactiveVerticalMarginConstant
            self.homeHeaderInfoText.attributedText = newAttributedLabel
            self.homeHeaderView.backgroundColor = UIColor.covidHomePermissionErrorColor
            topLeftIcon.isHidden = false
        } else {
            animatedBluetoothHeaderHeightConstraint.constant = animatedHeaderActiveHeightConstant
            animatedBluetoothHeaderTopMarginConstraint.constant = animatedHeaderActiveVerticalMarginConstant
            animatedBluetoothHeaderBottomMarginConstraint.constant = animatedHeaderActiveVerticalMarginConstant
            self.homeHeaderView.backgroundColor = UIColor.covidHomeActiveColor
            updateAnimationViewWithAnimationName(name: "Spinner_home")
            topLeftIcon.isHidden = true
        }
        
    }
    
    fileprivate func toggleBluetoothStatusView() {
        toggleViewVisibility(view: bluetoothStatusOnView, isVisible: !self.bluetoothPermissionOn && self.bluetoothStatusOn)
        toggleViewVisibility(view: bluetoothStatusOffView, isVisible: self.bluetoothPermissionOn && !self.bluetoothStatusOn)
    }
    
    fileprivate func toggleBluetoothPermissionStatusView() {
        toggleViewVisibility(view: bluetoothPermissionOnView, isVisible: !self.allPermissionOn && self.bluetoothPermissionOn)
        toggleViewVisibility(view: bluetoothPermissionOffView, isVisible: !self.allPermissionOn && !self.bluetoothPermissionOn)
    }
    
    fileprivate func togglePushNotificationsStatusView() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        switch self.pushNotificationOn {
        case true:
            pushNotificationContainerView.accessibilityLabel = "NotificationsEnabled_VOLabel".localizedString()
            pushNotificationStatusIcon.isHighlighted = false
            pushNotificationStatusTitle.text = NSLocalizedString("home_set_complete_external_link_notifications_title_iOS", comment: "Notifications Enabled")
            let newAttributedLabel = NSMutableAttributedString(string: NSLocalizedString("NotificationsEnabledBlurb", comment: "Notifications Enabled content blurb"), attributes: [.font: UIFont.preferredFont(forTextStyle: .callout)])

            //set some attributes
            guard let linkRange = newAttributedLabel.string.range(of: "NotificationsBlurbLink".localizedString( comment: "Notifications blurb link")) else { return }
            let nsRange = NSRange(linkRange, in: newAttributedLabel.string)
            newAttributedLabel.addAttribute(.foregroundColor,
                                     value: UIColor.covidSafeColor,
                                     range: nsRange)
            newAttributedLabel.addAttribute(.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, newAttributedLabel.length))
            pushNotificationStatusLabel.attributedText = newAttributedLabel
            
        default:
            pushNotificationContainerView.accessibilityLabel = "NotificationsDisabled_VOLabel".localizedString()
            pushNotificationStatusIcon.isHighlighted = true
            pushNotificationStatusTitle.text = "home_set_complete_external_link_notifications_title_iOS_off".localizedString(comment: "Notifications Disabled")
            let newAttributedLabel = NSMutableAttributedString(string:
                NSLocalizedString("NotificationsDisabledBlurb", comment: "Notifications Disabled content blurb"), attributes: [.font: UIFont.preferredFont(forTextStyle: .callout)])

            //set some attributes
            guard let linkRange = newAttributedLabel.string.range(of: "NotificationsBlurbLink".localizedString()) else { return }
            let nsRange = NSRange(linkRange, in: newAttributedLabel.string)
            newAttributedLabel.addAttribute(.foregroundColor,
                                     value: UIColor.covidSafeColor,
                                     range: nsRange)
            newAttributedLabel.addAttribute(.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, newAttributedLabel.length))
            pushNotificationStatusLabel.attributedText = newAttributedLabel
        }
    }
    
    func attemptTurnOnBluetooth() {
        BluetraceManager.shared.toggleScanning(false)
        BluetraceManager.shared.turnOn()
    }
    
    // MARK: IBActions
    
    @IBAction func onAppSettingsTapped(_ sender: UITapGestureRecognizer) {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }
    
    @IBAction func onChangeLanguageTapped(_ sender: UITapGestureRecognizer) {
        if #available(iOS 13.0, *) {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            UIApplication.shared.open(settingsURL)
        } else {
            let nav = HelpNavController()
            nav.pageSectionId = "other-languages"
            nav.modalTransitionStyle = .coverVertical
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true, completion: nil)
        }
        
    }
    
    @IBAction func onBluetoothPhoneSettingsTapped(_ sender: Any) {
        attemptTurnOnBluetooth()
    }
    
    @IBAction func onShareTapped(_ sender: UITapGestureRecognizer) {
        let shareText = TracerRemoteConfig.defaultShareText
        let activity = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = shareView
                
        present(activity, animated: true, completion: nil)
    }
    
    @IBAction func onLatestNewsTapped(_ sender: UITapGestureRecognizer) {
        // open in safari https://www.australia.gov.au
        guard let url = URL(string: "https://www.australia.gov.au") else {
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    @IBAction func getCoronaVirusApp(_ sender: UITapGestureRecognizer) {
        guard let url = URL(string: "https://www.health.gov.au/resources/apps-and-tools/coronavirus-australia-app") else {
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    @IBAction func bluetoothPairingTapped(_ sender: Any) {
        guard let url = URL(string: "\(URLHelper.getHelpURL())#bluetooth-pairing-request") else {
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    @IBAction func onPositiveButtonTapped(_ sender: UITapGestureRecognizer) {
        guard let helpVC = UIStoryboard(name: "UploadData", bundle: nil).instantiateInitialViewController() else {
            return
        }
        let nav = UploadDataNavigationController(rootViewController: helpVC)
        nav.modalTransitionStyle = .coverVertical
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
    
    @IBAction func onHelpButtonTapped(_ sender: Any) {
        let nav = HelpNavController()
        nav.modalTransitionStyle = .coverVertical
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
    
    @objc
    func appWillResignActive(_ notification: Notification) {
        self.lottieBluetoothView?.stop()
    }
    
    @objc
    func appWillEnterForeground(_ notification: Notification) {
        self.lottieBluetoothView?.play()
    }
    
    @objc
    func enableUserInteraction(_ notification: Notification) {
        self.view.isUserInteractionEnabled = true
        lottieBluetoothView?.play()
    }

    @objc
    func disableUserInteraction(_ notification: Notification) {
        self.view.isUserInteractionEnabled = false
        lottieBluetoothView?.stop()
    }

    @objc
    func enableDeferringSystemGestures(_ notification: Notification) {
        if #available(iOS 11.0, *) {
            _preferredScreenEdgesDeferringSystemGestures = .bottom
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
    }
    
    @objc
    func disableDeferringSystemGestures(_ notification: Notification) {
        if #available(iOS 11.0, *) {
            _preferredScreenEdgesDeferringSystemGestures = []
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
    }
}

struct TracerRemoteConfig {
    static let defaultShareText = """
        \("share_this_app_content".localizedString(comment: "Share app with friends text"))
        """
}
