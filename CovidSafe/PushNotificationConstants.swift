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
            "contentTitle": "COVIDSafe is currently inactive",
            "contentBody": "Make sure it's active before you leave home and when in public places by enabling Bluetooth®"
        ]
    ]
    
    static let reminderPushNotifContents = [
        "contentTitle": "Reminder: COVIDSafe app has not been active in the past 48 hours",
        "contentBody": "Tap to open the app and keep Bluetooth enabled."
    ]
}
