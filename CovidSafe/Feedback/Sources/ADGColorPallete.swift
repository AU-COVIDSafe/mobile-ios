//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

let ADGTintColor = UIColor(0x0052CC)
let ADGChromeColor = UIColor(0xF4F5F7)
let ADGHairlineColor = UIColor(0xEBECF0)
let ADGTextColor = UIColor(0x172B4D)
let ADGTextColorSecondary = UIColor(0xA5ADBA)

public enum NavigationBarStyle {
    case blue
    case white

    var backgroundColor: UIColor {
        switch self {
        case .blue: return ADGTintColor
        case .white: return UIColor.white
        }
    }

    var tintColor: UIColor {
        switch self {
        case .blue: return UIColor.white
        case .white: return ADGTintColor
        }
    }

    var titleTextColor: UIColor {
        switch self {
        case .blue: return UIColor.white
        case .white: return ADGTextColor
        }
    }

    var titleFont: UIFont { return UIFont.systemFont(ofSize: 17.0, weight: UIFont.Weight.medium) }

    var statusBarStyle: UIStatusBarStyle {
        switch self {
        case .blue: return .lightContent
        case .white: return .default
        }
    }

    public static var defaultStyle: NavigationBarStyle { return .blue }
}
