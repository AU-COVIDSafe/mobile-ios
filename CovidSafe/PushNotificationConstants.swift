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
            "contentTitle": "Turned Bluetooth off by mistake?",
            "contentBody": "Help stop the spread of COVID-19 by keeping your phone’s Bluetooth on until the outbreak is over."
        ]
    ]
    
    static let reminderPushNotifContents = [
        "contentTitle": "Reminder: COVIDSafe app has not been active in the past 48 hours",
        "contentBody": "Tap to open the app and keep Bluetooth enabled."
    ]
}
