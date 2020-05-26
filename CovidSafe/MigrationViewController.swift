//
//  MigrationViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import Lottie

class MigrationViewController: UIViewController {
    @IBOutlet weak var animationContainer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let migrationAnimation = AnimationView(name: "spinner_migrating_db")
        migrationAnimation.loopMode = .loop
        migrationAnimation.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: self.animationContainer.frame.size)
        self.animationContainer.addSubview(migrationAnimation)
        migrationAnimation.play()
    }
}
