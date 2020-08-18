import UIKit
import CoreData
import KeychainSwift

final class InfoViewController: UIViewController {
    @IBOutlet weak var identifierLabel: UILabel!
    @IBOutlet weak var devicesEncounteredLabel: UILabel!
    @IBOutlet weak var clearLogsButton: UIButton!
    @IBOutlet weak var advertisementSwitch: UISwitch!
    @IBOutlet weak var scanningSwitch: UISwitch!
    @IBOutlet weak var centralStateLabel: UILabel!
    @IBOutlet weak var obtainBluetoothStateButton: UIButton!
    @IBOutlet weak var peripheralStateLabel: UILabel!
    @IBOutlet weak var discoveredPeripheralsCountLabel: UILabel!
    @IBOutlet weak var silentNotificationsCountLabel: UILabel!
    @IBOutlet weak var apnTokenLabel: UILabel!
    private var devicesEncounteredCount: Int?
    
    @IBOutlet weak var versionNumLabel: UILabel!
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchDevicesEncounteredCount()
        self.identifierLabel.text = DeviceIdentifier.getID()
        self.versionNumLabel.text = "\(PlistHelper.getvalueFromInfoPlist(withKey: kCFBundleVersionKey as String) ?? "no commit hash")"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        advertisementSwitch.addTarget(self, action: #selector(self.advertisementSwitchChanged), for: UIControl.Event.valueChanged)
        scanningSwitch.addTarget(self, action: #selector(self.scanningSwitchChanged), for: UIControl.Event.valueChanged)
        clearLogsButton.addTarget(self, action:#selector(self.clearLogsButtonClicked), for: .touchUpInside)
        silentNotificationsCountLabel.text = "\(UserDefaults.standard.integer(forKey: "debugSilentNotificationCount"))"
        apnTokenLabel.text = UserDefaults.standard.string(forKey: "deviceTokenForAPN")
        
    }
    
    @IBAction func logoutBtn(_ sender: UIButton) {
        do {
            // do a logout if we still leave this button in
            performSegue(withIdentifier: "logoutToInitialVCSegue", sender: nil)
        } catch {
            print("Unable to log out")
        }
        
    }
    
    @IBAction func requestUploadOTP(_ sender: UIButton) {
        let keychain = KeychainSwift()
        guard let jwt = keychain.get("JWT_TOKEN") else {
            DLog("Error trying to upload when not logged in")
            return
        }
        InitiateUploadAPI.requestUploadOTP(session: jwt) { (success, error) in
            DLog("success? \(success) error \(String(describing: error))")
        }
    }
    
    func fetchDevicesEncounteredCount() {
                    guard let persistentContainer =
            EncounterDB.shared.persistentContainer else {
                return
        }
        let managedContext = persistentContainer.viewContext
        let fetchRequest = Encounter.fetchRequestForRecords()
        
        do {
            let devicesEncountered = try managedContext.fetch(fetchRequest)
            let uniqueIDs = Set(devicesEncountered.map { $0.timestamp })
            self.devicesEncounteredLabel.text = String(uniqueIDs.count)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
    
    @objc
    func advertisementSwitchChanged(mySwitch: UISwitch) {
        BluetraceManager.shared.toggleAdvertisement(mySwitch.isOn)
    }
    
    @objc
    func scanningSwitchChanged(mySwitch: UISwitch) {
        BluetraceManager.shared.toggleScanning(mySwitch.isOn)
    }
    
    @IBAction func dumpDBpressed(_ sender: UIButton) {
        var activityItems: [Any] = []
        let localStoreUrl = CovidPersistentContainer.defaultDirectoryURL().appendingPathComponent("tracer", isDirectory: false).appendingPathExtension("sqlite")
        activityItems.append(localStoreUrl)
        let localStoreUrlshm = CovidPersistentContainer.defaultDirectoryURL().appendingPathComponent("tracer", isDirectory: false).appendingPathExtension("sqlite-shm")
        if FileManager.default.fileExists(atPath: localStoreUrlshm.path) {
            activityItems.append(localStoreUrlshm)
        }
        let localStoreUrlwal = CovidPersistentContainer.defaultDirectoryURL().appendingPathComponent("tracer", isDirectory: false).appendingPathExtension("sqlite-wal")
        if FileManager.default.fileExists(atPath: localStoreUrlwal.path) {
            activityItems.append(localStoreUrlwal)
        }
        let activity = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        present(activity, animated: true, completion: nil)
    }
    
    @objc
    func clearLogsButtonClicked() {
        guard let persistentContainer =
            EncounterDB.shared.persistentContainer else {
                return
        }
        let managedContext = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<Encounter>(entityName: "Encounter")
        fetchRequest.includesPropertyValues = false
        do {
            let encounters = try managedContext.fetch(fetchRequest)
            for encounter in encounters {
                managedContext.delete(encounter)
            }
            try managedContext.save()
        } catch {
            print("Could not perform delete. \(error)")
        }
        
        guard let logPersistentContainer =
            BLELogDB.shared.persistentContainer else {
                return
        }
        let logManagedContext = logPersistentContainer.viewContext
        let logFetchRequest = NSFetchRequest<BLELog>(entityName: "BLELog")
        logFetchRequest.includesPropertyValues = false
        do {
            let logs = try logManagedContext.fetch(logFetchRequest)
            for bleLog in logs {
                logManagedContext.delete(bleLog)
            }
            try logManagedContext.save()
        } catch {
            print("Could not perform delete. \(error)")
        }
    }
    
    @IBAction func resetSilentNotificationsCounter(_ sender: Any) {
        UserDefaults.standard.set(0, forKey: "debugSilentNotificationCount")
        silentNotificationsCountLabel.text = "0"
    }
}
