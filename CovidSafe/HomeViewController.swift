import UIKit
import Lottie
import KeychainSwift
import SafariServices
import Reachability

class HomeViewController: UIViewController {
    private var observer: NSObjectProtocol?
    
    @IBOutlet weak var bluetoothStatusOffView: UIView!
    @IBOutlet weak var bluetoothPermissionOffView: UIView!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var inactiveAppSectionView: UIView!
    @IBOutlet weak var activeAppSectionView: UIView!
    @IBOutlet weak var covidInactiveLabel: UILabel!
    @IBOutlet weak var covidActiveLabel: UILabel!
    @IBOutlet weak var animatedBluetoothHeader: UIView!
    @IBOutlet weak var versionNumberLabel: UILabel!
    @IBOutlet weak var versionView: UIView!
    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var uploadDateView: UIView!
    @IBOutlet weak var uploadDateLabel: UILabel!
    @IBOutlet weak var pairingRequestsLabel: UILabel!
    @IBOutlet weak var appActiveSubtitleLabel: UILabel!
    @IBOutlet weak var uploadDataContentLabel: UILabel!
    @IBOutlet weak var uploadDataTitleLabel: UILabel!
    @IBOutlet weak var covidStatisticsContainer: UIView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var statisticsSectionHeight: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var appActiveSubtitleLabelInitialColor: UIColor?
    
    var lottieBluetoothView: AnimationView!

    let covidStatisticsViewController: CovidStatisticsViewController = CovidStatisticsViewController(nibName: "CovidStatisticsView", bundle: nil)
    
    var allPermissionOn = true
    var bluetoothStatusOn = true
    var bluetoothPermissionOn = true
    var pushNotificationOn = true
    var shouldShowUpdateApp = false
    
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
                                             value: UIFont.preferredFont(for: .body, weight: .bold),
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
    
    private let reachability = try! Reachability()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scrollView.refreshControl = UIRefreshControl()
        scrollView.refreshControl?.addTarget(self, action: #selector(refreshControlEvent), for: .valueChanged)
        
        
        // this is to show the settings prompt initially if bluetooth is off
        if !BluetraceManager.shared.isBluetoothOn() {
            BluetraceManager.shared.turnOn()
        }
        
        observer = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [unowned self] notification in
            self.refreshView()
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
        
        uploadDataTitleLabel.font = UIFont.preferredFont(for: .title3, weight: .bold)
        uploadDataContentLabel.font = UIFont.preferredFont(for: .callout, weight: .bold)
        covidInactiveLabel.font = UIFont.preferredFont(for: .title3, weight: .bold)
        appActiveSubtitleLabelInitialColor = appActiveSubtitleLabel.textColor
        
        setupStatisticsView()
        getStatistics()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        do {
          try reachability.startNotifier()
        } catch {
          DLog("Could not start reachability notifier")
        }
        self.toggleViews()
        if !UserDefaults.standard.bool(forKey: "PerformHealthChecks") {
            DispatchQueue.global(qos: .background).async {
                self.getMessagesFromServer()
            }
        }
        performHealthCheck()
        covidStatisticsViewController.statisticsDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.lottieBluetoothView?.play()
        self.becomeFirstResponder()
        self.updateJWTKeychainAccess()
        
        if shouldShowPolicyUpdateMessage() {
            showPolicyUpdateMessage()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.lottieBluetoothView?.stop()
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
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
    
    fileprivate func refreshView() {
        toggleViews()
        performHealthCheck()
        getStatistics()
    }
    
    fileprivate func setupStatisticsView() {
        addChild(covidStatisticsViewController)
        covidStatisticsViewController.view.translatesAutoresizingMaskIntoConstraints = false
        covidStatisticsContainer.addSubview(covidStatisticsViewController.view)
        
        NSLayoutConstraint.activate([
            covidStatisticsViewController.view.leadingAnchor.constraint(equalTo: covidStatisticsContainer.leadingAnchor),
            covidStatisticsViewController.view.trailingAnchor.constraint(equalTo: covidStatisticsContainer.trailingAnchor),
            covidStatisticsViewController.view.topAnchor.constraint(equalTo: covidStatisticsContainer.topAnchor),
            covidStatisticsViewController.view.bottomAnchor.constraint(equalTo: covidStatisticsContainer.bottomAnchor)
        ])
        covidStatisticsViewController.didMove(toParent: self)
    }
    
    fileprivate func toggleViews() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { [weak self] settings in
                DispatchQueue.main.async {
                    self?.readPermissions(notificationSettings: settings)
                    
                    self?.toggleBluetoothStatusView()
                    self?.toggleBluetoothPermissionStatusView()
                    self?.toggleHeaderView()
                    self?.toggleUploadView()
                    self?.toggleUploadDateView()
                }
            })
        }
    }
    
    fileprivate func performHealthCheck() {
        if UserDefaults.standard.bool(forKey: "PerformHealthChecks") {
            UserDefaults.standard.set(false, forKey: "PerformHealthChecks")
            guard allPermissionOn else {
                // if all permission not ON, stay in home screen
                return
            }
            
            getMessagesFromServer(force: true) {
            
                if  (self.reachability.connection != .cellular && self.reachability.connection != .wifi) ||
                    self.shouldShowUpdateApp {
                    DispatchQueue.main.async {
                        self.onSettingsTapped(self)
                    }
                } else if self.allPermissionOn &&
                    self.isInternetReachable() &&
                    !self.shouldShowUpdateApp {
                    DispatchQueue.main.async {
                        self.covidActiveLabel.text = "home_header_active_title_thanks".localizedString()
                    }
                }
            }
        }
    }
    
    fileprivate func isInternetReachable() -> Bool {
        return reachability.connection == .cellular || reachability.connection == .wifi
    }
    
    fileprivate func toggleUploadDateView() {
        if shouldShowUploadDate, let lastUploadText = self.dataUploadedAttributedString {
            uploadDateLabel.attributedText = lastUploadText
            uploadDateView.isHidden = false
        } else {
            uploadDateView.isHidden = true
        }
    }
    
    fileprivate func readPermissions(notificationSettings: UNNotificationSettings) {
        self.bluetoothStatusOn = BluetraceManager.shared.isBluetoothOn()
        self.bluetoothPermissionOn = BluetraceManager.shared.isBluetoothAuthorized()
        self.pushNotificationOn = notificationSettings.authorizationStatus == .authorized
        let newAllPermissionsOn = self.bluetoothStatusOn && self.bluetoothPermissionOn
            
        if newAllPermissionsOn != self.allPermissionOn {
            self.allPermissionOn = newAllPermissionsOn
            DispatchQueue.global(qos: .background).async {
                self.getMessagesFromServer(force: true)
            }
        }
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
        toggleViewVisibility(view: inactiveAppSectionView, isVisible: !self.allPermissionOn)
        toggleViewVisibility(view: activeAppSectionView, isVisible: self.allPermissionOn)
    }
    
    fileprivate func toggleBluetoothStatusView() {
        toggleViewVisibility(view: bluetoothStatusOffView, isVisible: self.bluetoothPermissionOn && !self.bluetoothStatusOn)
    }
    
    fileprivate func toggleBluetoothPermissionStatusView() {
        toggleViewVisibility(view: bluetoothPermissionOffView, isVisible: !self.allPermissionOn && !self.bluetoothPermissionOn)
    }
    
    func attemptTurnOnBluetooth() {
        BluetraceManager.shared.toggleScanning(false)
        BluetraceManager.shared.turnOn()
    }
    
    fileprivate func updateAppActiveSubtitle() {
        let haveInternet = self.reachability.connection == .cellular || self.reachability.connection == .wifi
        if shouldShowUpdateApp || !haveInternet {
            appActiveSubtitleLabel.font = UIFont.preferredFont(for: .callout, weight: .bold)
            appActiveSubtitleLabel.textColor = UIColor.covidSafeErrorColor
            appActiveSubtitleLabel.text = "improve".localizedString()
        } else {
            appActiveSubtitleLabel.font = UIFont.preferredFont(for: .callout, weight: .regular)
            appActiveSubtitleLabel.textColor = appActiveSubtitleLabelInitialColor
            appActiveSubtitleLabel.text = "home_header_active_no_action_required".localizedString()
        }
    }
    
    // MARK: policy update message
    
    func shouldShowPolicyUpdateMessage() -> Bool {
        // this is the min version that the disclamer should be diplayed on.
        let minVersionShowPolicyUpdate = 77
        
        let latestVersionShown = UserDefaults.standard.integer(forKey: "latestPolicyUpdateVersionShown")
        guard let currentVersion = (Bundle.main.version as NSString?)?.integerValue else {
            return false
        }
        if currentVersion >= minVersionShowPolicyUpdate && currentVersion > latestVersionShown {
            UserDefaults.standard.set(currentVersion, forKey: "latestPolicyUpdateVersionShown")
            return true
        }
        return false
    }
    
    func showPolicyUpdateMessage() {
        
        let privacyPolicyUrl = URLHelper.getPrivacyPolicyURL()
        let disclaimerAlert = CSAlertViewController(nibName: "CSAlertView", bundle: nil)
        let disclaimerMsg = NSMutableAttributedString(string: "collection_message".localizedString(), attributes: [.font : UIFont.preferredFont(forTextStyle: .body)])
        disclaimerMsg.addLink(enclosedIn: "*", urlString: privacyPolicyUrl)
        disclaimerAlert.set(message: disclaimerMsg, buttonLabel: "dismiss".localizedString())
        
        disclaimerAlert.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        disclaimerAlert.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        present(disclaimerAlert, animated: true, completion: nil)
    }
    
    // MARK: API calls
    
    func getMessagesFromServer(force: Bool = false, completion: @escaping () -> Void = {}) {
        let onMessagesDone: (MessageResponse?, Swift.Error?) -> Void = { (messageResponse, error) in
            if let error = error {
                DLog("Get messages error: \(error.localizedDescription)")
                completion()
                return
            }
            
            // show update available section
            guard let messages = messageResponse?.messages else {
                self.shouldShowUpdateApp = false
                DispatchQueue.main.async {
                    self.updateAppActiveSubtitle()
                }
                completion()
                return
            }
            
            self.shouldShowUpdateApp = messages.count > 0
            DispatchQueue.main.async {
                self.updateAppActiveSubtitle()
            }
            NotificationCenter.default.post(name: .shouldUpdateAppFromMessages, object: nil)
            completion()
        }
        
        if force {
            MessageAPI.getMessages(completion: onMessagesDone)
        } else {
            MessageAPI.getMessagesIfNeeded(completion: onMessagesDone)
        }
    }
    
    func getStatistics() {
        if covidStatisticsViewController.showStatistics {
            self.covidStatisticsViewController.isLoading = true
            StatisticsAPI.getStatistics { (stats, error) in
                self.covidStatisticsViewController.isLoading = false
                self.covidStatisticsViewController.setupData(statistics: stats, errorType: error, hasInternet: self.isInternetReachable())
            }
        }
    }
    
    // MARK: Reachability
    
    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability
        
        switch reachability.connection {
        case .wifi,
             .cellular:
            updateAppActiveSubtitle()
        case .unavailable,
             .none:
            updateAppActiveSubtitle()
        }
    }
    
    // MARK: IBActions
    
    @IBAction func onAppSettingsTapped(_ sender: UITapGestureRecognizer) {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }
    
    @IBAction func noInternetTapped(_ sender: Any) {
        performSegue(withIdentifier: "internetConnectionSegue", sender: nil)
    }
    
    @IBAction func updateAvailableTapped(_ sender: Any) {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id1509242894"),
            UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @IBAction func onChangeLanguageTapped(_ sender: UITapGestureRecognizer) {
        let nav = HelpNavController()
        nav.pageSectionId = "other-languages"
        nav.modalTransitionStyle = .coverVertical
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
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
    
    @IBAction func bluetoothPairingTapped(_ sender: Any) {
        guard let url = URL(string: "\(URLHelper.getHelpURL())#bluetooth-pairing-request") else {
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    @IBAction func onPositiveButtonTapped(_ sender: UITapGestureRecognizer) {
        guard let uploadVC = UIStoryboard(name: "UploadData", bundle: nil).instantiateInitialViewController() else {
            return
        }
        navigationController?.pushViewController(uploadVC, animated: true)
    }
    
    @IBAction func onHelpButtonTapped(_ sender: Any) {
        let nav = HelpNavController()
        nav.modalTransitionStyle = .coverVertical
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
    
    @IBAction func improvementAvailableTapped(_ sender: Any) {
        if shouldShowUpdateApp || !isInternetReachable() {
            onSettingsTapped(sender)
        }
    }
    
    @IBAction func onSettingsTapped(_ sender: Any) {
        let settingsVC = SettingsViewController(nibName: "SettingsView", bundle: nil)
        settingsVC.showUpdateAvailable = shouldShowUpdateApp
        navigationController?.pushViewController(settingsVC, animated: true)
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
    
    @objc
    func refreshControlEvent() {
        refreshView()
        DispatchQueue.main.async {
            self.scrollView.refreshControl?.endRefreshing()
        }
    }
}

// MARK: Statistics delegate

extension HomeViewController: StatisticsDelegate {
    
    func refreshStatistics() {
        self.getStatistics()
    }
    
    func setStatisticsContainerHeight(height: CGFloat) {
        
        self.statisticsSectionHeight.constant = height
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}

struct TracerRemoteConfig {
    static let defaultShareText = """
        \("share_this_app_content".localizedString(comment: "Share app with friends text"))
        """
}
