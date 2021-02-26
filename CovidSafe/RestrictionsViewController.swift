//
//  RestrictionsViewController.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import UIKit

class RestrictionsViewController: CovidHeaderContentViewController {
    
    let restrictionsTableViewController: RestrictionTableViewController = RestrictionTableViewController(nibName: "RestrictionTableView", bundle: nil)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        tabBarItem.title = "restrictions_heading".localizedString()
        tabBarItem.image = UIImage(named: "unlock")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = "restrictions_heading".localizedString()
        
        setupContentView(contentView: restrictionsTableViewController.view)
    }
    
    override func setupContentView(contentView: UIView) {
        addChild(restrictionsTableViewController)
        super.setupContentView(contentView: contentView)
        restrictionsTableViewController.didMove(toParent: self)
    }
}
