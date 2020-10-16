import UIKit
import Lottie
import KeychainSwift
import SafariServices
import Reachability

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var versionNumberLabel: UILabel!
    @IBOutlet weak var versionView: UIView!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var pushNotificationStatusTitle: UILabel!
    @IBOutlet weak var pushNotificationStatusIcon: UIImageView!
    @IBOutlet weak var pushNotificationStatusLabel: UILabel!
    @IBOutlet weak var pushNotificationContainerView: UIView!
    
    @IBOutlet weak var improvementsContainerView: UIView!
    @IBOutlet weak var improvementsInternetConnectionView: UIView!
    @IBOutlet weak var improvementsUpdateAvailableView: UIView!
    
    var pushNotificationOn = true
    var showUpdateAvailable = false
    var initialLabelTextColour: UIColor?

    private let reachability = try! Reachability()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initialLabelTextColour = pushNotificationStatusTitle.textColor
        
        if let versionNumber = Bundle.main.versionShort, let buildNumber = Bundle.main.version {
            self.versionNumberLabel.text = String.localizedStringWithFormat(
                "home_version_number_ios".localizedString(comment: "Version number template"),
                versionNumber,buildNumber
            )
        } else {
            toggleViewVisibility(view: versionView, isVisible: false)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(shouldUpdateNotificationReceived), name: .shouldUpdateAppFromMessages, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActiveNotificationReceived), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        improvementsUpdateAvailableView.isHidden = !showUpdateAvailable
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        do {
          try reachability.startNotifier()
        } catch {
          DLog("Could not start reachability notifier")
        }
        self.toggleViews()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }
    
    fileprivate func toggleViews() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { [weak self] settings in
                DispatchQueue.main.async {
                    self?.readPermissions(notificationSettings: settings)
                    self?.togglePushNotificationsStatusView()
                    self?.toggleImprovementsContainerView()
                }
            })
        }
    }
    
    fileprivate func readPermissions(notificationSettings: UNNotificationSettings) {
        self.pushNotificationOn = notificationSettings.authorizationStatus == .authorized
    }
    
    fileprivate func toggleViewVisibility(view: UIView, isVisible: Bool) {
        view.isHidden = !isVisible
    }
    
    fileprivate func togglePushNotificationsStatusView() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        switch self.pushNotificationOn {
        case true:
            pushNotificationContainerView.accessibilityLabel = "NotificationsEnabled_VOLabel".localizedString()
            pushNotificationStatusIcon.isHighlighted = false
            pushNotificationStatusTitle.text = NSLocalizedString("home_set_complete_external_link_notifications_title_iOS", comment: "Notifications Enabled")
            pushNotificationStatusTitle.textColor = initialLabelTextColour
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
            pushNotificationStatusTitle.textColor = UIColor.covidSafeErrorColor
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
    
    fileprivate func toggleImprovementsContainerView() {
        // only show if the app has the right settings
        let areChildrenShown = !improvementsUpdateAvailableView.isHidden || !improvementsInternetConnectionView.isHidden
        
        toggleViewVisibility(view: improvementsContainerView, isVisible: areChildrenShown)
    }
    
    fileprivate func toggleInternetConnectionView(isVisible: Bool) {
        toggleViewVisibility(view: improvementsInternetConnectionView, isVisible: isVisible)
        toggleImprovementsContainerView()
    }
    
    fileprivate func toggleAppVersionAvailableView(isVisible: Bool) {
        toggleViewVisibility(view: improvementsUpdateAvailableView, isVisible: isVisible)
        toggleImprovementsContainerView()
    }
    
    // MARK: Reachability
    
    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability
        
        switch reachability.connection {
        case .wifi,
             .cellular:
            toggleInternetConnectionView(isVisible: false)
        case .unavailable,
             .none:
            toggleInternetConnectionView(isVisible: true)
        }
    }
    
    // MARK: Observer Methods
    
    @objc func shouldUpdateNotificationReceived() {
        showUpdateAvailable = true
        improvementsUpdateAvailableView.isHidden = !showUpdateAvailable
        toggleViews()
    }
    
    @objc func didBecomeActiveNotificationReceived() {
        toggleViews()
    }
    
    // MARK: IBActions
    
    @IBAction func onAppSettingsTapped(_ sender: UITapGestureRecognizer) {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }
    
    @IBAction func noInternetTapped(_ sender: Any) {
        let nav = InternetConnectionViewController(nibName: "InternetConnectionView", bundle: nil)
        nav.modalTransitionStyle = .coverVertical
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
    
    @IBAction func updateAvailableTapped(_ sender: Any) {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id1509242894"),
            UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @IBAction func onShareTapped(_ sender: UITapGestureRecognizer) {
        let shareText = TracerRemoteConfig.defaultShareText
        let activity = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = shareView
                
        present(activity, animated: true, completion: nil)
    }
    
    @IBAction func onSupportTapped(_ sender: Any) {
        do {
            let feedbackSettings = try FeedbackSettings(navigationBarStyle: .white)
            self.presentFeedback(false, settings: feedbackSettings)
        } catch {
            DLog("Error retrieving feedback settings: \(error.localizedDescription)")
        }
    }
    
    @IBAction func onHelpButtonTapped(_ sender: Any) {
        let nav = HelpNavController()
        nav.modalTransitionStyle = .coverVertical
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
    
    @IBAction func onBackTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}
