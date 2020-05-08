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
        Encounter.timestamp(for: .appStarted)
        let firstRun = UserDefaults.standard.bool(forKey: "HasBeenLaunched")
        if( !firstRun ) {
            let keychain = KeychainSwift()
            keychain.clear()
            UserDefaults.standard.set(true, forKey: "HasBeenLaunched")
        }
        
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
        
        setupBluetoothPNStatusCallback()
        
        motionManager = CMMotionManager()
        startAccelerometerUpdates()
        
        // Remote config setup
        let _ = TracerRemoteConfig()
        
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
                }
            }
        }
    }
    
    fileprivate func triggerCalendarLocalPushNotifications(pnContent: [String : String], identifier: String) {
        
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = pnContent["contentTitle"]!
        content.body = pnContent["contentBody"]!
        
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
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
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: CovidPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = CovidPersistentContainer(name: "tracer")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        DLog("applicationDidBecomeActive")
        Encounter.timestamp(for: .appEnteredForeground)
        
        startAccelerometerUpdates()
        clearOldDataInContext()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        DLog("applicationWillResignActive")
        // Retry in case it failed on become active
        clearOldDataInContext()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        DLog("applicationDidEnterBackground")
        Encounter.timestamp(for: .appEnteredBackground)
        
        let magicNumber = Int.random(in: 0 ... PushNotificationConstants.dailyRemPushNotifContents.count - 1)
        
        self.dismissBlackscreen()
        stopAccelerometerUpdates()
        
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        triggerCalendarLocalPushNotifications(pnContent: PushNotificationConstants.dailyRemPushNotifContents[magicNumber], identifier: "appBackgroundNotifId")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        DLog("applicationWillEnterForeground")
        self.dismissBlackscreen()
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        DLog("applicationWillTerminate")
        Encounter.timestamp(for: .appTerminating)
        
        stopAccelerometerUpdates()
    }
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
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
                let managedContext = self.persistentContainer.viewContext
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
}

extension Notification.Name {
    static let enableDeferringSystemGestures = Notification.Name("enableDeferringSystemGestures")
    static let disableDeferringSystemGestures = Notification.Name("disableDeferringSystemGestures")
    static let disableUserInteraction = Notification.Name("disableUserInteraction")
    static let enableUserInteraction = Notification.Name("enableUserInteraction")
    static let jwtExpired = Notification.Name("jwtExpired")
}

@available(iOS 10, *)
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
        }
        completionHandler()
    }
}
