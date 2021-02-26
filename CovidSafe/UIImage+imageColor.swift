//
//  UIImage+imageColor.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import UIKit

extension UIImage {
    class func imageWithColor(color: UIColor, topBorderColor: UIColor, size: CGSize) -> UIImage {
        let rect: CGRect = CGRect(x: 0.0, y: 0.0, width: Double(size.width), height: Double(size.height))
        let topRect: CGRect = CGRect(x: 0.0, y: 0.0, width: Double(size.width), height: Double(3.0))
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        topBorderColor.setFill()
        UIRectFill(topRect)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
