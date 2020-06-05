//
//  OnboardingStep2bViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class OnboardingStep2bViewController: UIViewController {
    @IBOutlet weak var pointOneLabel: UILabel!
    @IBOutlet weak var pointTwoLabel: UILabel!
    @IBOutlet weak var pointThreeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 18.0
        let labelAtt: [NSAttributedString.Key : Any] = [
            .paragraphStyle: paragraphStyle,
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]
        let pointOneText = NSAttributedString(string: NSLocalizedString("PointOne", comment: "Keep phone on you when you leave home"),
                                                     attributes: labelAtt)
        pointOneLabel.attributedText = pointOneText
        
        let pointTwoText = NSAttributedString(string: NSLocalizedString("PointTwo", comment: "Keep bluetooth turned on"),
                                                     attributes: labelAtt)
        pointTwoLabel.attributedText = pointTwoText
        
        let pointThreeText = NSMutableAttributedString(string: NSLocalizedString("PointThree", comment: "COVIDSafe does NOT send pairing requests"),
                                                     attributes: labelAtt)
        let learnMoreRange = pointThreeText.string.range(of: NSLocalizedString("PointThreeUnderline", comment: "Text that should be underlined from PointThree"))!
        let nsRange = NSRange(learnMoreRange, in: pointThreeText.string)
        pointThreeText.addAttributes([.underlineStyle: NSUnderlineStyle.single.rawValue, .foregroundColor: UIColor.covidSafeColor], range: nsRange)
        pointThreeLabel.attributedText = pointThreeText
    }
    
    @IBAction func learnMoreTapped(_ sender: Any) {
        guard let url = URL(string: "https://www.covidsafe.gov.au/help-topics.html#bluetooth-pairing-request") else {
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    @IBAction func continueBtnTapped(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showHomeSegue", sender: self)
    }
}
