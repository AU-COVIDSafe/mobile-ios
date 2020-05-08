//
//  IsolationSuccessViewController.swift
//  CovidSafe
//
//  Created on 20/4/20.
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

class IsolationSuccessViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let center = UNUserNotificationCenter.current()
        //remove all pending notifications
        center.removePendingNotificationRequests(withIdentifiers: ["dailyUploadReminder"])
        UserDefaults.standard.set(0, forKey: "firstUploadDataDate")
    }
    

    @IBAction func doneOntap(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
