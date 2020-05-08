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
    
    // Daily Reminders
    static let dailyRemPushNotifContents = [
        [
            "contentTitle": "Check if COVIDSafe is active",
            "contentBody": "Don't forget to check if COVIDSafe is active before you leave home and when in public places."
        ]
    ]
}
