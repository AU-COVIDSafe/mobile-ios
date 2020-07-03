//
//  UILocalization.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//
import UIKit
import Foundation

extension UIView {
    static var localizedKey:UInt8 = 0
    static var localizedVOLabelKey:UInt8 = 1
    static var localizedVOHintKey:UInt8 = 2
    
    @IBInspectable public var localVOLabelKey: String? {
        set {
            objc_setAssociatedObject(self, &UIView.localizedVOLabelKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UIView.localizedVOLabelKey) as? String
        }
    }
    
    @IBInspectable public var localVOHintKey: String? {
        set {
            objc_setAssociatedObject(self, &UIView.localizedVOHintKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UIView.localizedVOHintKey) as? String
        }
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        if let localizedVOLabelKey = self.localVOLabelKey, localizedVOLabelKey != localizedVOLabelKey.localizedString() {
            self.accessibilityLabel = localizedVOLabelKey.localizedString()
        }
        if let localizedVOHintKey = self.localVOHintKey, localizedVOHintKey != localizedVOHintKey.localizedString() {
            self.accessibilityHint = localizedVOHintKey.localizedString()
        }
    }
}

extension UILabel {

    @IBInspectable public var localizationKey: String? {
        set {
            objc_setAssociatedObject(self, &UILabel.localizedKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UILabel.localizedKey) as? String
        }
    }
    
    @IBInspectable public override var localVOLabelKey: String? {
        set {
            objc_setAssociatedObject(self, &UILabel.localizedVOLabelKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UILabel.localizedVOLabelKey) as? String
        }
    }
    
    @IBInspectable public override var localVOHintKey: String? {
        set {
            objc_setAssociatedObject(self, &UILabel.localizedVOHintKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UILabel.localizedVOHintKey) as? String
        }
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        if let localizationKey = self.localizationKey, localizationKey != localizationKey.localizedString() {
            self.text = localizationKey.localizedString()
        }
    }
}

extension UITextView {

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

    @IBInspectable public var localizationKey: String? {
        set {
            objc_setAssociatedObject(self, &UITextField.localizedKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UITextField.localizedKey) as? String
        }
    }
    
    @IBInspectable public override var localVOLabelKey: String? {
        set {
            objc_setAssociatedObject(self, &UITextField.localizedVOLabelKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UITextField.localizedVOLabelKey) as? String
        }
    }
    
    @IBInspectable public override var localVOHintKey: String? {
        set {
            objc_setAssociatedObject(self, &UITextField.localizedVOHintKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UITextField.localizedVOHintKey) as? String
        }
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        
        if let localizationKey = self.localizationKey, localizationKey != localizationKey.localizedString() {
            self.placeholder = localizationKey.localizedString()
        }
    }
}

extension UIButton {

    @IBInspectable public var localizationKey: String? {
        set {
            objc_setAssociatedObject(self, &UIButton.localizedKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UIButton.localizedKey) as? String
        }
    }
    
    @IBInspectable public override var localVOLabelKey: String? {
        set {
            objc_setAssociatedObject(self, &UIButton.localizedVOLabelKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UIButton.localizedVOLabelKey) as? String
        }
    }
    
    @IBInspectable public override var localVOHintKey: String? {
        set {
            objc_setAssociatedObject(self, &UIButton.localizedVOHintKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &UIButton.localizedVOHintKey) as? String
        }
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        if let localizationKey = self.localizationKey, localizationKey != localizationKey.localizedString() {
            self.setTitle(localizationKey.localizedString(), for: .normal)
        }
    }
}
