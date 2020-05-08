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
        obtainBluetoothStateButton.addTarget(self, action:#selector(self.obtainBluetoothStateButtonClicked), for: .touchUpInside)
        
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
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = Encounter.fetchRequestForRecords()
        
        do {
            let devicesEncountered = try managedContext.fetch(fetchRequest)
            let uniqueIDs = Set(devicesEncountered.map { $0.msg })
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
    
    @objc
    func clearLogsButtonClicked() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
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
    }
    
    @objc
    func obtainBluetoothStateButtonClicked() { }
}
