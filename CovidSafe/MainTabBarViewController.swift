//
//  MainTabBarViewController.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import UIKit

class MainTabBarViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // add tabs
        let homeVC = HomeViewController(nibName: "HomeView", bundle: nil)
        let settingsVC = SettingsViewController(nibName: "SettingsView", bundle: nil)
        let restrictionsVC = RestrictionsViewController(nibName: "RestrictionsView", bundle: nil)
        
        viewControllers = [homeVC, restrictionsVC, settingsVC]
        
        // style the tabs
        tabBar.layer.borderWidth = 1
        tabBar.clipsToBounds = true
        tabBar.layer.borderColor = UIColor.covidSafeColor.cgColor
        tabBar.barTintColor = UIColor.covidHomeActiveColor
        tabBar.unselectedItemTintColor = UIColor.black
        tabBar.tintColor = UIColor.covidSafeColor    
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // set tab bar background color
        let numberOfItems = CGFloat(tabBar.items!.count)
        let tabBarItemSize = CGSize(width: tabBar.frame.width/numberOfItems, height: tabBar.frame.height)
        
        tabBar.selectionIndicatorImage = UIImage
            .imageWithColor(color: UIColor.covidSafeButtonDarkerColor.withAlphaComponent(0.15), topBorderColor: UIColor.covidSafeButtonDarkerColor, size: tabBarItemSize)
            .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
    }

}
