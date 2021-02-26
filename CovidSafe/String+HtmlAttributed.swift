//
//  String+HtmlAttributed.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import UIKit

extension String {
    func htmlDocumentString(font: UIFont, withAdditionalCSS: String = "") -> String {
        let htmlTemplate = """
        <!doctype html>
        <html>
          <head>
            <style>
              body {
                font-family: -apple-system;
                font-size: \(font.pointSize)px;
              }
                \(withAdditionalCSS)
            </style>
          </head>
          <body>
            \(self)
          </body>
        </html>
        """

        return htmlTemplate
    }
    
    func htmlDocumentAttributedString(font: UIFont, withAdditionalCSS: String = "") -> NSAttributedString? {
        let htmlTemplate = """
        <!doctype html>
        <html>
          <head>
            <style>
              body {
                font-family: -apple-system;
                font-size: \(font.pointSize)px;
              }
                \(withAdditionalCSS)
            </style>
          </head>
          <body>
            \(self)
          </body>
        </html>
        """

        guard let data = htmlTemplate.data(using: .unicode) else {
            return nil
        }
        
        guard let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
            ) else {
            return nil
        }

        return attributedString
    }
}
