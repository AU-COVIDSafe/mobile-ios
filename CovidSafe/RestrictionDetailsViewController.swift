//
//  RestrictionDetailsViewController.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import UIKit
import SafariServices

class RestrictionDetailsViewController: CovidHeaderContentViewController {
    
    var htmlString: String?
    var hasLoadedInitialContent = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let restrictionsDetailsView = Bundle.main.loadNibNamed("WebContentView", owner: self, options: nil)?.first as? WebContentView else {
            return
        }
        
        restrictionsDetailsView.webContentView.delegate = self
        restrictionsDetailsView.webContentView.scrollView.showsVerticalScrollIndicator = false
        restrictionsDetailsView.webContentView.scrollView.showsHorizontalScrollIndicator = false
        
        guard let htmlString = self.htmlString else { return  }
        restrictionsDetailsView.webContentView.loadHTMLString(htmlString.htmlDocumentString(font: UIFont.preferredFont(forTextStyle: .body), withAdditionalCSS: "a{color:\(UIColor.covidSafeButtonDarkerColor.hexString)}"), baseURL: nil)
        setupContentView(contentView: restrictionsDetailsView)
    }
    
}

extension RestrictionDetailsViewController: UIWebViewDelegate {
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        hasLoadedInitialContent = true
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        
        if !hasLoadedInitialContent {
            return true
        }
        
        guard let urlToLoad = request.url else {
            return false
        }
        
        let safariVC = SFSafariViewController(url: urlToLoad)
            present(safariVC, animated: true, completion: nil)
        
        return false
    }
    
}
