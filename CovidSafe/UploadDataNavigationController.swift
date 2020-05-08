//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

final class UploadDataNavigationController: UINavigationController {
    
    let emptyTextBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.tintColor = UIColor.covidSafeColor
        navigationBar.backIndicatorImage = UIImage(named: "arrow-left")
        navigationBar.backIndicatorTransitionMaskImage = UIImage(named: "arrow-left")
        navigationBar.barTintColor = .white
        navigationBar.shadowImage = UIImage()
        setNavigationBarHidden(true, animated: false)
    }
}

extension UploadDataNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        viewController.navigationItem.backBarButtonItem = emptyTextBarButtonItem
    }
}
