//
//  UILocalization.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//
import UIKit
import Foundation

extension UILabel {
    
    static var localizedKey:UInt8 = 0

    @IBInspectable public var localizationKey: String? {
        set {
            objc_setAssociatedObject(self, &UILabel.localizedKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UILabel.localizedKey) as? String
        }
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        guard let localizationKey = self.localizationKey, localizationKey != localizationKey.localizedString() else {
            return
        }
        self.text = localizationKey.localizedString()
    }
}

extension UITextView {
    static var localizedKey:UInt8 = 0

    @IBInspectable public var localizationKey: String? {
        set {
            objc_setAssociatedObject(self, &UITextView.localizedKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UITextView.localizedKey) as? String
        }
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        guard let localizationKey = self.localizationKey, localizationKey != localizationKey.localizedString() else {
            return
        }
        self.text = localizationKey.localizedString()
    }
}

extension UITextField {
    static var localizedKey:UInt8 = 0

    @IBInspectable public var localizationKey: String? {
        set {
            objc_setAssociatedObject(self, &UITextView.localizedKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UITextView.localizedKey) as? String
        }
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        guard let localizationKey = self.localizationKey, localizationKey != localizationKey.localizedString() else {
            return
        }
        self.placeholder = localizationKey.localizedString()
    }
}

extension UIButton {
    static var localizedKey:UInt8 = 0

    @IBInspectable public var localizationKey: String? {
        set {
            objc_setAssociatedObject(self, &UITextView.localizedKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UITextView.localizedKey) as? String
        }
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        guard let localizationKey = self.localizationKey, localizationKey != localizationKey.localizedString() else {
            return
        }
        self.setTitle(localizationKey.localizedString(), for: .normal)
    }
}
