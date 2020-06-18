//
//  PushNotificationConstants.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

struct PushNotificationConstants {
    // Bluetooth Status
    static let btStatusPushNotifContents = [
        [
            "contentTitle": "PN_BluetoothStatusTitle".localizedString(),
            "contentBody": "PN_BluetoothStatusBody".localizedString()
        ]
    ]
    
    static let reminderPushNotifContents = [
        "contentTitle": "PN_ReminderTitle".localizedString(),
        "contentBody": "PN_ReminderBody".localizedString()
    ]
}
