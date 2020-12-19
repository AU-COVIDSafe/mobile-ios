//
//  CSGenericContentViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class CSGenericContentViewController: UIViewController {
    
    @IBOutlet weak var stepCounterLabel: UILabel!
    @IBOutlet weak var contentIllustration: UIImageView!
    @IBOutlet weak var contentTitleLabel: UILabel!
    @IBOutlet weak var contentDescriptionText: UITextView!
    @IBOutlet weak var actionButton: UIButton!
    
    var contentViewModel: CSGenericContentViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let viewModel = contentViewModel else {
            return
        }
        
        // set the step counter
        if let contentStep = viewModel.contentStepNumber, let contentTotal = viewModel.contentStepTotal {
            stepCounterLabel.text = String.localizedStringWithFormat( "stepCounter".localizedString(),
                contentStep,
                contentTotal
            )
        } else {
            stepCounterLabel.text = ""
            stepCounterLabel.isHidden = true
        }
        
        // set the illustration
        if let illustration = viewModel.contentIllustration {
            contentIllustration.image = illustration
        }
        
        // set title and content
        contentTitleLabel.text = viewModel.viewTitle
        contentDescriptionText.attributedText = viewModel.viewContentDescription
        contentDescriptionText.parseHTMLTags()
        contentDescriptionText.addAllBold(enclosedIn: "#")
        
        //set button label and action
        actionButton.setTitle(viewModel.buttonLabel, for: .normal)
        actionButton.addTarget(self, action: #selector(pressed), for: .touchUpInside)
    }
    
    @objc func pressed(sender: UIButton!) {
        guard let viewModel = contentViewModel else {
            return
        }
        
        viewModel.buttonCallback()
    }
    
}

struct CSGenericContentViewModel {
    var viewTitle: String
    var viewContentDescription: NSAttributedString
    var buttonLabel: String
    var buttonCallback: () -> Void
    var contentIllustration: UIImage?
    var contentStepNumber: Int?
    var contentStepTotal: Int?
}
