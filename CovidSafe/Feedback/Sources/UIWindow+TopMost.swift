//  Copyright © 2017 Australian Government All rights reserved.

import UIKit

extension UIWindow {
    public var topmostPresentedViewController: UIViewController? {
        return rootViewController?.topmostPresentedViewController
    }
}

extension UIViewController {
    public var topmostPresentedViewController: UIViewController {
        return presentedViewController?.topmostPresentedViewController ?? self
    }
}
