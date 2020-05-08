//  Copyright © 2020 Australian Government All rights reserved.

import WebKit
import UIKit

class HelpNavController: UINavigationController {

    private static let HELP_PAGE_URL = URLHelper.getHelpURL()

    private let loader = UIActivityIndicatorView(style: .gray)
    let webview = WKWebView()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.setNavigationBarHidden(true, animated: false)

        setup()
        loadHelp()
    }

    private func setup() {
        webview.navigationDelegate = self
        webview.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(named: "closeButton")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        closeButton.tintColor = .covidSafeColor

        let feedbackButton = UIButton(type: .system)
        feedbackButton.translatesAutoresizingMaskIntoConstraints = false
        feedbackButton.addTarget(self, action: #selector(feedbackButtonPressed(_:)), for: .touchUpInside)
        feedbackButton.setTitle("Report an issue", for: .normal)
        feedbackButton.titleLabel?.font = .systemFont(ofSize: 18)
        feedbackButton.tintColor = .covidSafeColor
        
        let dividerLine = UIView()
        dividerLine.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            dividerLine.backgroundColor = .secondarySystemFill
        } else {
            dividerLine.backgroundColor = UIColor(0xe9e9eb)
        }

        view.addSubview(closeButton)
        view.addSubview(feedbackButton)
        view.addSubview(dividerLine)
        view.addSubview(webview)

        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                closeButton.centerYAnchor.constraint(equalTo: feedbackButton.centerYAnchor),
                closeButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                
                feedbackButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                feedbackButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
                
                webview.topAnchor.constraint(equalTo: dividerLine.bottomAnchor),
                webview.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                webview.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                webview.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                closeButton.centerYAnchor.constraint(equalTo: feedbackButton.centerYAnchor),
                closeButton.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                
                feedbackButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 16.0),
                feedbackButton.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

                webview.topAnchor.constraint(equalTo: dividerLine.bottomAnchor),
                webview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }
        
        NSLayoutConstraint.activate([
            dividerLine.topAnchor.constraint(equalTo: feedbackButton.bottomAnchor),
            dividerLine.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dividerLine.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dividerLine.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])
    }

    private func loadHelp() {
        guard let url = URL(string: HelpNavController.HELP_PAGE_URL) else {
            assertionFailure("Invalid URL: \(HelpNavController.HELP_PAGE_URL)")
            return
        }

        showLoader()
        webview.load(URLRequest(url: url))
    }

    private func showLoader() {
        loader.translatesAutoresizingMaskIntoConstraints = false
        webview.addSubview(loader)

        NSLayoutConstraint.activate([
            loader.centerYAnchor.constraint(equalTo: webview.centerYAnchor),
            loader.centerXAnchor.constraint(equalTo: webview.centerXAnchor),
        ])
        loader.startAnimating()
    }

    private func hideLoader() {
        loader.stopAnimating()
        loader.removeFromSuperview()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @objc func feedbackButtonPressed(_ sender: Any) {
        do {
            let feedbackSettings = try FeedbackSettings(navigationBarStyle: .white)
            self.presentFeedback(false, settings: feedbackSettings)
        } catch {
            preconditionFailure("Error retrieving feedback settings: \(error.localizedDescription)")
        }
    }

    @objc private func close() {
        dismiss(animated: true, completion: nil)
    }
}

extension HelpNavController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoader()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url,
            url.absoluteString != HelpNavController.HELP_PAGE_URL else {
                decisionHandler(.allow)
                return
        }

        let app = UIApplication.shared
        if app.canOpenURL(url) {
            app.open(url, options: [:], completionHandler: nil)
        }
        decisionHandler(.cancel)
    }
}
