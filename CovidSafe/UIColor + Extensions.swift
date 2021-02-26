//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

extension UIColor {
    static let covidHomeActiveColor = UIColor(0xC8FFB9)
    static let covidHomePermissionErrorColor = UIColor(0xE2E2E2)
    static let covidSafeColor = UIColor(0x00661B)
    static let covidSafeDarkFontColor = UIColor(0x131313)
    static let covidSafeLighterColor = UIColor(0x008A23)
    static let covidSafeLightGreyColor = UIColor(0xDDDDDD)
    static let covidSafeButtonDarkerColor = UIColor(0x00661B)
    static let covidSafeErrorColor = UIColor(0xA31919)
    
    var asSolidBackgroundImage: UIImage {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context!.setFillColor(self.cgColor)
        context!.fill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }
    
    var hexString: String {
        let components = self.cgColor.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0

        let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
        return hexString
     }
}
