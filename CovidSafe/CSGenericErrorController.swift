//
//  CSGenericErrorViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class CSGenericErrorViewController: UIViewController {
    
    @IBOutlet weak var errorTitleLabel: UILabel!
    @IBOutlet weak var errorDescriptionText: UILabel!
    @IBOutlet weak var mainButton: UIButton!
    @IBOutlet weak var secondaryButton: UIButton!
    
    var errorViewModel: CSGenericErrorViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let viewModel = errorViewModel else {
            return
        }
        
        // set title and content
        errorTitleLabel.font = UIFont.preferredFont(for: .title3, weight: .semibold)
        errorTitleLabel.text = viewModel.errorTitle
        errorDescriptionText.text = viewModel.errorContentDescription
        
        //set button label and action
        mainButton.setTitle(viewModel.mainButtonLabel, for: .normal)
        mainButton.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
        
        //set button label and action
        secondaryButton.setTitle(viewModel.secondaryButtonLabel, for: .normal)
        secondaryButton.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
    }
    
    @objc func buttonPressed(sender: UIButton!) {
        if sender == mainButton {
            self.dismiss(animated: true, completion: errorViewModel?.mainButtonCallback)
        } else if sender == secondaryButton {
            self.dismiss(animated: true, completion:  errorViewModel?.secondaryButtonCallback)
        }
    }
    
    @IBAction func closeBtnTapped(_ sender: Any) {
        dismiss(animated: true)
    }
}

struct CSGenericErrorViewModel {
    var errorTitle: String
    var errorContentDescription: String
    var mainButtonLabel: String
    var mainButtonCallback: (() -> Void)?
    var secondaryButtonLabel: String
    var secondaryButtonCallback: (() -> Void)?
}
