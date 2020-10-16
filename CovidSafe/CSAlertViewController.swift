//
//  CSAlertViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class CSAlertViewController: UIViewController {
    
    @IBOutlet weak var messageLabel: UITextView!
    @IBOutlet weak var mainButton: UIButton!
    
    private var message: NSAttributedString?
    private var buttonLabel: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        messageLabel.attributedText = message
        mainButton.setTitle(buttonLabel, for: .normal)
    }
    
    func set(message: NSAttributedString, buttonLabel: String) {
        self.message = message
        self.buttonLabel = buttonLabel
    }
    
    @IBAction func onMainActionTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension CSAlertViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.dismiss(animated: true, completion: nil)
        })        
        return true
    }
}
