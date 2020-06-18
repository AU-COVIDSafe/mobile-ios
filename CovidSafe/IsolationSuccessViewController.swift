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
}
