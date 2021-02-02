//
//  ExternalLinkTableViewCell.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class ExternalLinkTableViewCell: UITableViewCell {

    @IBOutlet weak var cellImage: UIImageView!
    @IBOutlet weak var linkDescription: UILabel!
    var externalLinkURL: URL?
    
    @IBAction func openExternalLinkTapped(_ sender: Any) {
        guard let linkToOpen = externalLinkURL else {
            return
        }
        
        let safariVC = SFSafariViewController(url: linkToOpen)
        UIApplication.shared.keyWindow?.rootViewController?.present(safariVC, animated: true, completion: nil)
        
    }
}
