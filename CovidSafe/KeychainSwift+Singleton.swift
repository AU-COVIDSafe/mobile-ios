//
//  KeychainSwift+Singleton.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import Foundation
import KeychainSwift

extension KeychainSwift {
    static var shared = KeychainSwift()
}
