//  Copyright © 2020 Australian Government All rights reserved.

import Foundation
import UIKit

class Question3ViewController: UIViewController {

    @IBOutlet var messageTextView: UITextView!
    @IBOutlet var noButton: UIButton!
    @IBOutlet var yesButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMessageTextView()
        setupButtons()
    }
    
    private func setupButtons() {
        noButton.setTitleColor(.white, for: .highlighted)
        noButton.setBackgroundImage(UIColor.covidSafeColor.asSolidBackgroundImage, for: .highlighted)

        yesButton.setTitleColor(.white, for: .highlighted)
        yesButton.setBackgroundImage(UIColor.covidSafeColor.asSolidBackgroundImage, for: .highlighted)
    }
    
    private func setupMessageTextView() {
        messageTextView.textContainer.lineFragmentPadding = 0.0
        messageTextView.addLink("https://www.australia.gov.au", enclosedIn: "*")
    }    
}
