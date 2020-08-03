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
        NotificationCenter.default.addObserver(self, selector:#selector(deferReminderNotifications(_:)),name: .encounterRecorded, object: nil)
        
        setupBluetoothPNStatusCallback()
        
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
    
    fileprivate func setupBluetoothPNStatusCallback() {
        
        let btStatusMagicNumber = Int.random(in: 0 ... PushNotificationConstants.btStatusPushNotifContents.count - 1)
        
        BluetraceManager.shared.bluetoothDidUpdateStateCallback = { [unowned self] state in
            guard state != .resetting else {
                // If the bt is just resetting no need to prompt the user here
                return
            }
            if UserDefaults.standard.bool(forKey: "turnedOnBluetooth") && !BluetraceManager.shared.isBluetoothOn() {
                if !UserDefaults.standard.bool(forKey: "sentBluetoothStatusNotif") {
                    UserDefaults.standard.set(true, forKey: "sentBluetoothStatusNotif")
                    self.triggerIntervalLocalPushNotifications(pnContent: PushNotificationConstants.btStatusPushNotifContents[btStatusMagicNumber], identifier: "bluetoothStatusNotifId")
                    return
                }
            }
            switch state {                
            case .poweredOff, .unauthorized:
                DLog("*** Setup reminders - BL OFF, UNAUTH check/set reminders")
                self.checkAndScheduleReminderNotifications()
            default:
                // leave reminder notifications as they are, when an encounter occurs the notifications will be deferred
                // or removed when app becomes active
                DLog("*** Setup reminders - Default leave reminders")
            }
        }
    }
    
    fileprivate func getReminderNotificationsIdentifiers() -> [String] {
        var identifiers: [String] = []
        for interval in intervals {
            identifiers.append(getReminderNotificationIdentifier(interval: interval))
        }
        return identifiers
    }
    
    fileprivate func cancelScheduledReminderNotifications() {
        DLog("*** Cancel reminders")
        let identifiers = getReminderNotificationsIdentifiers()
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
    
    fileprivate func checkAndScheduleReminderNotifications() {
        let identifiers = getReminderNotificationsIdentifiers()
        DLog("*** Setup reminders - checking pending reminders")
        // check all reminders are scheduled and pending
        UNUserNotificationCenter.current().getPendingNotificationRequests { (notificationsRequest) in
            var scheduledRemindersCount = 0
            for notification in notificationsRequest {
                if identifiers.firstIndex(of: notification.identifier) != nil {
                    scheduledRemindersCount += 1
                }
            }
            // re-schedule reminders unless they are all pending
            if scheduledRemindersCount != identifiers.count {
                self.scheduleReminderNotifications()
            }
        }
    }
        
    fileprivate func scheduleReminderNotifications() {
        DLog("*** Set reminders")
        let reminderContent = PushNotificationConstants.reminderPushNotifContents
        guard
            let title = reminderContent["contentTitle"],
            let body = reminderContent["contentBody"] else {
                return
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        
        for interval in intervals {
            let content = UNMutableNotificationContent()
            let identifier = getReminderNotificationIdentifier(interval: interval)
            #if DEBUG
                content.title = "\(title) \(interval / 60) min"
            #else
                content.title = title
            #endif
            
            content.body = body
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            notificationCenter.add(request)
        }
    }
    
    @objc
    func deferReminderNotifications(_ notification: Notification) {
        // no need to cancel, if same ID used the notification is updated
        scheduleReminderNotifications()
    }
    
    // - Application lifecycle
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        DLog("applicationDidBecomeActive")
        
        startAccelerometerUpdates()
        clearOldDataInContext()
        
        // if Bluetooth is ON, remove reminders, leave otherwise.
        if BluetraceManager.shared.isBluetoothOn() {
            cancelScheduledReminderNotifications()
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        DLog("applicationWillResignActive")
        // Retry in case it failed on become active
        clearOldDataInContext()
        
        // check if reminders pending and set if needed
        checkAndScheduleReminderNotifications()
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
                let managedContext = persistentContainer.viewContext
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
        
        MessageAPI.getMessagesIfNeeded(completion: { (response, error) in
            if let error = error {
                DLog("Get messages error: \(error.localizedDescription)")
                return
            }
            DLog("Get messages success, device token saved")
        })
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
        
        if payload["content-available"] as? Int == 1 && payload["category"] as? String == "UPDATE_STATS" {
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
            
            if notificationType == "UPDATE_APP",
            let url = URL(string: "itms-apps://itunes.apple.com/app/id1509242894"),
            UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        completionHandler()
    }
}
