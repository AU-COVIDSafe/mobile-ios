//
//  UIFont + Traits.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

extension UIFont {
    
    static func preferredFont(for style: TextStyle, weight: Weight) -> UIFont {
        if #available(iOS 11.0, *) {
            let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            let font = UIFont.systemFont(ofSize: desc.pointSize, weight: weight)
            return font
        } else {
            if weight == .bold {
                return UIFont.preferredFont(forTextStyle: style).bold()
            }
            return UIFont.preferredFont(forTextStyle: style)
        }
    }
    
    func withTraits(traits:UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            //unable to get descriptor, leave as is and do not add traits
            return self
        }
        return UIFont(descriptor: descriptor, size: 0) //size 0 means keep the size as it is
    }

    func bold() -> UIFont {
        return withTraits(traits: .traitBold)
    }

    func italic() -> UIFont {
        return withTraits(traits: .traitItalic)
    }
}
