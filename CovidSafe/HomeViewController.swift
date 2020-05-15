import UIKit
import Lottie
import SafariServices

class HomeViewController: UIViewController {
    private var observer: NSObjectProtocol?
    
    @IBOutlet weak var screenStack: UIStackView!
    @IBOutlet weak var bluetoothStatusOffView: UIView!
    @IBOutlet weak var bluetoothStatusOnView: UIView!
    @IBOutlet weak var bluetoothPermissionOffView: UIView!
    @IBOutlet weak var bluetoothPermissionOnView: UIView!
    @IBOutlet weak var homeHeaderView: UIView!
    @IBOutlet weak var homeHeaderInfoText: UILabel!
    @IBOutlet weak var homeHeaderPermissionsOffImage: UIImageView!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var thanksForTheHelp: UIView!
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
    
    var lottieBluetoothView: AnimationView!

    var allPermissionOn = true
    var bluetoothStatusOn = true
    var bluetoothPermissionOn = true
    var pushNotificationOn = true
    var didUploadData: Bool {
        let uploadTimestamp = UserDefaults.standard.double(forKey: "uploadDataDate")
        let lastUpload = Date(timeIntervalSince1970: uploadTimestamp)
        return Date().timeIntervalSince(lastUpload) < 86400 * 21
    }
    var shouldShowEndOfIsolationScreen: Bool {
        let uploadTimestamp = UserDefaults.standard.double(forKey: "firstUploadDataDate")
        if(uploadTimestamp > 0){
            let lastUpload = Date(timeIntervalSince1970: uploadTimestamp)
            return Date().timeIntervalSince(lastUpload) >= 86400 * 21
        }
        return false
    }
    
    var _preferredScreenEdgesDeferringSystemGestures: UIRectEdge = []
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return _preferredScreenEdgesDeferringSystemGestures
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
            self.versionNumberLabel.text = "Version number: \(versionNumber) Build: \(buildNumber)"
        } else {
            toggleViewVisibility(view: versionView, isVisible: false)
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
        
        if(shouldShowEndOfIsolationScreen){
           self.performSegue(withIdentifier: "IsolationSuccessSegue", sender: self)
        }
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
                }
            })
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
        toggleViewVisibility(view: thanksForTheHelp, isVisible: self.allPermissionOn && self.didUploadData)
        toggleViewVisibility(view: homeHeaderPermissionsOffImage, isVisible: !self.allPermissionOn)
        toggleViewVisibility(view: lottieBluetoothView, isVisible: self.allPermissionOn)
        
        if (self.allPermissionOn && self.didUploadData) {
            self.homeHeaderInfoText.textColor = UIColor.white
        } else {
            self.homeHeaderInfoText.textColor = UIColor(0x131313)
        }
        self.helpButton.setImage(UIImage(named: "ic-help-selected"), for: .normal)
        self.helpButton.setTitleColor(UIColor.black, for: .normal)
        
        self.homeHeaderInfoText.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        self.homeHeaderInfoText.text = "COVIDSafe is active.\nNo further action is required."
        
        if (!self.allPermissionOn) {
            self.homeHeaderInfoText.text = "COVIDSafe is not active.\nCheck your permissions."
            self.homeHeaderView.backgroundColor = UIColor.covidHomePermissionErrorColor
        } else if (self.didUploadData) {
            self.helpButton.setImage(UIImage(named: "ic-help"), for: .normal)
            self.helpButton.setTitleColor(UIColor.white, for: .normal)
            self.homeHeaderInfoText.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            self.homeHeaderView.backgroundColor = UIColor.covidSafeButtonDarkerColor
            updateAnimationViewWithAnimationName(name: "Spinner_home_upload_complete")
        } else {
            self.homeHeaderView.backgroundColor = UIColor.covidHomeActiveColor
            updateAnimationViewWithAnimationName(name: "Spinner_home")
        }
        
    }
    
    fileprivate func toggleBluetoothStatusView() {
        toggleViewVisibility(view: bluetoothStatusOnView, isVisible: !self.allPermissionOn && self.bluetoothStatusOn)
        toggleViewVisibility(view: bluetoothStatusOffView, isVisible: !self.allPermissionOn && !self.bluetoothStatusOn)
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
            pushNotificationStatusIcon.isHighlighted = false
            pushNotificationStatusTitle.text = "Notifications are enabled"
            let newAttributedLabel = NSMutableAttributedString(string: "You will receive a notification if COVIDSafe is not active.  Change notification settings")

            //set some attributes
            guard let linkRange = newAttributedLabel.string.range(of: "Change notification settings") else { return }
            let nsRange = NSRange(linkRange, in: newAttributedLabel.string)
            newAttributedLabel.addAttribute(.foregroundColor,
                                     value: UIColor.covidSafeColor,
                                     range: nsRange)
            newAttributedLabel.addAttribute(.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, newAttributedLabel.length))
            pushNotificationStatusLabel.attributedText = newAttributedLabel
            
        default:
            pushNotificationStatusIcon.isHighlighted = true
            pushNotificationStatusTitle.text = "Notifications are disabled"
            let newAttributedLabel = NSMutableAttributedString(string: "You will not receive a notification if COVIDSafe is not active.  Change notification settings")

            //set some attributes
            guard let linkRange = newAttributedLabel.string.range(of: "Change notification settings") else { return }
            let nsRange = NSRange(linkRange, in: newAttributedLabel.string)
            newAttributedLabel.addAttribute(.foregroundColor,
                                     value: UIColor.covidSafeColor,
                                     range: nsRange)
            newAttributedLabel.addAttribute(.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, newAttributedLabel.length))
            pushNotificationStatusLabel.attributedText = newAttributedLabel
        }
    }
    
    @IBAction func onSettingsTapped(_ sender: UITapGestureRecognizer) {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
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
    
    @IBAction func onPowerSaverButtonTapped(_ sender: Any) {
        
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
        Join me in stopping the spread of COVID-19! Download COVIDSafe, an app from the Australian Government. #COVID19
        #coronavirusaustralia #stayhomesavelives https://covidsafe.gov.au
        """
}
