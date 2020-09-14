import UIKit
import CoreData
import CoreMotion
import KeychainSwift

func DLog(_ message: String, file:NSString = #file, line: Int = #line, functionName: String = #function) {
    #if DEBUG
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS "
    print("[\(formatter.string(from: Date()))][\(file.lastPathComponent):\(line)][\(functionName)]: \(message)")
    #endif
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var motionManager : CMMotionManager!
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid // this is a task to clear data when going to background
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupCoredataDir()
        let firstRun = UserDefaults.standard.bool(forKey: "HasBeenLaunched")
        if( !firstRun ) {
            let keychain = KeychainSwift()
            keychain.clear()
            UserDefaults.standard.set(true, forKey: "HasBeenLaunched")
        }
        
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.covidSafeColor], for: .normal)
        UINavigationBar.appearance().tintColor = UIColor.covidSafeColor
        
        let hasUserConsent = true
        let hasUserCompletedOnboarding = UserDefaults.standard.bool(forKey: "turnedOnBluetooth")
        let bluetoothAuthorised = BluetraceManager.shared.isBluetoothAuthorized()
        if (hasUserConsent && hasUserCompletedOnboarding && bluetoothAuthorised) {
            BluetraceManager.shared.turnOn()
        } else {
            print("Onboarding not yet done.")
        }
        EncounterMessageManager.shared.setup()
        UIApplication.shared.isIdleTimerDisabled = true
        
        UNUserNotificationCenter.current().delegate = self
        NotificationCenter.default.addObserver(self, selector:#selector(jwtExpired(_:)),name: .jwtExpired, object: nil)
        
        motionManager = CMMotionManager()
        startAccelerometerUpdates()
        
        // Remote config setup
        let _ = TracerRemoteConfig()
        
        registerForPushNotifications()

        return true
    }
    
    func setupCoredataDir() {
        do {
            let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            var newDir = appSupport.appendingPathComponent("covidsafe", isDirectory: true)
            if (!FileManager.default.fileExists(atPath: newDir.path)) {
                try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true, attributes: nil)
            }
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try newDir.setResourceValues(resourceValues)
        } catch {
            DLog("Unable to create directory and set attributes for coredata store \(error.localizedDescription)")
        }
    }
    
    @objc
    func jwtExpired(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let regVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "onboardingStep3") as? PhoneNumberViewController else {
                return
            }
            regVC.reauthenticating = true
            regVC.modalPresentationStyle = .overFullScreen
            regVC.modalTransitionStyle = .coverVertical
            let navigationController = UINavigationController(rootViewController: regVC)
            navigationController.setToolbarHidden(true, animated: false)
            if #available(iOS 13.0, *) {
                navigationController.isModalInPresentation = true
            }
            self.window?.topmostPresentedViewController?.present(navigationController, animated: true, completion: nil)
        }
    }
    
    // - Local Notifications
    
    fileprivate func getReminderNotificationsIdentifiers() -> [String] {
        var identifiers: [String] = []
        for interval in intervals {
            identifiers.append(getReminderNotificationIdentifier(interval: interval))
        }
        return identifiers
    }
    
    fileprivate func cancelScheduledReminderNotifications() {
        DLog("*** Cancel reminders")
        var identifiers = getReminderNotificationsIdentifiers()
        // appending the old daily notification to cancel in case is still lingering
        identifiers.append("appBackgroundNotifId")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        
    }
        
    fileprivate func triggerIntervalLocalPushNotifications(pnContent: [String : String], identifier: String) {
        
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = pnContent["contentTitle"]!
        content.body = pnContent["contentBody"]!
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    
    #if DEBUG
        let intervals: [TimeInterval] = [60, 15 * 60, 30 * 60, 60 * 60, 120 * 60]
    #else
        let intervals: [TimeInterval] = [TimeInterval(60 * 60 * 48)]
    #endif

    fileprivate func getReminderNotificationIdentifier(interval: TimeInterval) -> String {
        return "reminder-\(interval)"
    }
    
    // MARK: - Application lifecycle
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        DLog("applicationDidBecomeActive")
        
        startAccelerometerUpdates()
        clearOldDataInContext()
        
        // remove old reminders
        cancelScheduledReminderNotifications()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        DLog("applicationWillResignActive")
        // Retry in case it failed on become active
        clearOldDataInContext()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        DLog("applicationDidEnterBackground")
        
        self.dismissBlackscreen()
        stopAccelerometerUpdates()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        DLog("applicationWillEnterForeground")
        self.dismissBlackscreen()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        DLog("applicationWillTerminate")
        
        stopAccelerometerUpdates()
    }
    
    func clearOldDataInContext() {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        let today = calendar.startOfDay(for: Date())
        
        var shouldCleanData = false
        if let dateStored = UserDefaults.standard.value(forKey: "lastTimeDataCleaned") as? Date {
            shouldCleanData = dateStored < today
        } else {
            // if date does not exist simply add today as initial value
            UserDefaults.standard.setValue(today, forKey: "lastTimeDataCleaned")
        }
        
        if(shouldCleanData) {
            registerBackgroundTask()
            let dispatchQueue = DispatchQueue(label: "DeleteOldData", qos: .background)
            dispatchQueue.async{
                guard let persistentContainer = EncounterDB.shared.persistentContainer else {
                    self.endBackgroundTask()
                    return
                }
                let managedContext = persistentContainer.newBackgroundContext()
                if let oldFetchRequest = Encounter.fetchOldEncounters() {
                    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: oldFetchRequest)
                    do {
                        try managedContext.execute(batchDeleteRequest)
                        // set cleaned date on success only
                        UserDefaults.standard.setValue(today, forKey: "lastTimeDataCleaned")
                    } catch {
                        // old data deletion failed!
                        // since the lastTimeDataCleaned is not set it will be retried hopefully same day and succeed
                        
                        //fatalError("Failed to execute request: \(error)")
                    }
                    self.endBackgroundTask()
                }
            }
        }
    }
    
      
    // - Wallpaper with watermark
    
    let blackScreenTag = 123
    
    private func showBlackscreen() {
        if window?.viewWithTag(blackScreenTag) == nil {
            let powerSavingView = UIView()
            powerSavingView.frame = window!.frame
            powerSavingView.tag = blackScreenTag
            powerSavingView.contentMode = .scaleAspectFit
            powerSavingView.backgroundColor = .black
            powerSavingView.alpha = 0

            let appNameImage = UIImageView(image: UIImage(named: "lowPowerLogo"))
            appNameImage.frame = powerSavingView.frame
            appNameImage.contentMode = .center
            powerSavingView.addSubview(appNameImage)

            window?.addSubview(powerSavingView)
            UIView.animate(withDuration: 0.5) {
                powerSavingView.alpha = 1
            }
            
            NotificationCenter.default.post(name: .disableUserInteraction, object: nil)
            NotificationCenter.default.post(name: .enableDeferringSystemGestures, object: nil)
        }
    }
    
    private func dismissBlackscreen() {
        if window?.viewWithTag(blackScreenTag) != nil {
            let powerSavingView = window?.viewWithTag(blackScreenTag)
            powerSavingView?.alpha = 0
            powerSavingView?.removeFromSuperview()
            
            NotificationCenter.default.post(name: .enableUserInteraction, object: nil)

            NotificationCenter.default.post(name: .disableDeferringSystemGestures, object: nil)
        }
    }
    
    var sampleAngleY = [Double]()
    var sampleAngleZ = [Double]()
    
    fileprivate func appendYSample(sample: Double)  {
        sampleAngleY.append(sample)
        if(sampleAngleY.count > 10){
            sampleAngleY.removeFirst()
        }
    }
    
    fileprivate func appendZSample(sample: Double)  {
        sampleAngleZ.append(sample)
        if(sampleAngleZ.count > 10){
            sampleAngleZ.removeFirst()
        }
    }
    
    func startAccelerometerUpdates() {
        let splitAngle:Double = 0.75
        let updateTimer:TimeInterval = 0.35
        
        motionManager?.accelerometerUpdateInterval = updateTimer
        
        motionManager?.startAccelerometerUpdates(to: (OperationQueue.current)!, withHandler: { [weak self]
            (acceleroMeterData, error) -> Void in
            if error == nil {
                let acceleration = (acceleroMeterData?.acceleration)!
                self?.appendYSample(sample: acceleration.y)
                self?.appendZSample(sample: acceleration.z)
                
                guard let accelerationYSum = self?.sampleAngleY.reduce(0.0, +), let accelerationZSum = self?.sampleAngleZ.reduce(0.0, +),
                    let countY = self?.sampleAngleY.count, let countZ = self?.sampleAngleZ.count else {
                    return
                }
                let accelerationYAvg = accelerationYSum / Double(countY)
                let accelerationZAvg = accelerationZSum / Double(countZ)
                
                if accelerationYAvg >= splitAngle || accelerationZAvg >= splitAngle {
                    self?.showBlackscreen()
                    
                } else {
                    self?.dismissBlackscreen()
                }
            } else {
                print("error : \(error!)")
            }
        })
    }

    func stopAccelerometerUpdates() {
        motionManager?.stopAccelerometerUpdates()
    }
    
    // - Background tasking
    
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
      
    func endBackgroundTask() {
        if(backgroundTask != .invalid){
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // - Remote Push Notifications
    
    func registerForPushNotifications() {
        // check if permission have been requested, if so, is an existing user and we should register
        // otherwise the permission will be set in the apprpiate permissions screen
        guard UserDefaults.standard.bool(forKey: "allowedPermissions") == true else {
            return
        }
        
        // existing user registering for RPN
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Attach the device token to the user defaults
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        DLog("The APN token received is: \(token)")
        
        UserDefaults.standard.set(token, forKey: "deviceTokenForAPN")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DLog("Remote notification received")
        
        guard let payload = userInfo["aps"] as? [String: AnyObject] else {
          completionHandler(.failed)
          return
        }
        
        #if DEBUG
        // for debug build only, log all silent notifications regardless of the category
        if payload["content-available"] as? Int == 1 {
            var numNotifications = UserDefaults.standard.integer(forKey: "debugSilentNotificationCount")
            numNotifications += 1
            UserDefaults.standard.set(numNotifications, forKey: "debugSilentNotificationCount")
        }
        #endif
        
        if payload["content-available"] as? Int == 1 && payload["category"] as? String == PushNotificationCategory.UPDATE_STATS {
            DLog("Notification is category: UPDATE_STATS")
            MessageAPI.getMessagesIfNeeded() { (messageResponse, error) in
                if let error = error {
                    DLog("Get messages error: \(error.localizedDescription)")
                    completionHandler(.failed)
                    return
                }
                DLog("Messages API success")
                completionHandler(.newData)
            }
            return
        }
        completionHandler(.noData)
        
    }
}

extension Notification.Name {
    static let enableDeferringSystemGestures = Notification.Name("enableDeferringSystemGestures")
    static let disableDeferringSystemGestures = Notification.Name("disableDeferringSystemGestures")
    static let disableUserInteraction = Notification.Name("disableUserInteraction")
    static let enableUserInteraction = Notification.Name("enableUserInteraction")
    static let jwtExpired = Notification.Name("jwtExpired")
    static let encounterRecorded = Notification.Name("encounterRecorded")
    static let shouldUpdateAppFromMessages = Notification.Name("shouldUpdateAppFromMessages")
}

struct PushNotificationCategory {
    static let UPDATE_STATS = "UPDATE_STATS"
    static let UPDATE_APP = "UPDATE_APP"
    static let POSSIBLE_ISSUE = "POSSIBLE_ISSUE"
    static let NO_CHECKIN = "NO_CHECKIN"
    static let POSSIBLE_ENCOUNTER_ERROR = "POSSIBLE_ENCOUNTER_ERROR"
}

extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // when user receives the notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == "bluetoothStatusNotifId" && !BluetraceManager.shared.isBluetoothAuthorized() {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            completionHandler()
            return
        }
        DLog("Remote notification received")
        let userInfo = response.notification.request.content.userInfo
        
        // check payload and notification type
        if let payload = userInfo["aps"] as? [String: AnyObject],
            let notificationType = payload["category"] as? String {
            
            if notificationType == PushNotificationCategory.UPDATE_APP,
            let url = URL(string: "itms-apps://itunes.apple.com/app/id1509242894"),
            UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            else if notificationType == PushNotificationCategory.POSSIBLE_ISSUE ||
                notificationType == PushNotificationCategory.NO_CHECKIN ||
                notificationType == PushNotificationCategory.POSSIBLE_ENCOUNTER_ERROR {
                UserDefaults.standard.set(true, forKey: "PerformHealthChecks")
            }
        }
        completionHandler()
    }
}
