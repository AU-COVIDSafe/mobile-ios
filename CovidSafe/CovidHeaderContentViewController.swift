//
//  CovidHeaderContentViewController.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import UIKit

class CovidHeaderContentViewController: UIViewController {
    
    @IBOutlet weak var contentContainer: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var backButtonContainer: UIView!
    
    var hideBackButton = true
    var hideSubtitle = true
    
    var titleString: String?
    var subtitleString: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        subtitleLabel.isHidden = hideSubtitle
        backButtonContainer.isHidden = hideBackButton
        
        titleLabel.text = titleString
        subtitleLabel.text = subtitleString
    }
    
    func setupContentView(contentView: UIView) {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
    }
    @IBAction func backButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}
