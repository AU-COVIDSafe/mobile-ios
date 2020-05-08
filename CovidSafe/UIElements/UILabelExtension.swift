import UIKit

extension UILabel {
    func semiBold(text: String) {
        guard let lblTxt = self.text,
            let range = lblTxt.range(of: text)  else { return }
        let nsRange = NSRange(range, in: lblTxt)
        let attrString = NSMutableAttributedString(string: lblTxt)
        attrString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 16, weight: .semibold), range: nsRange)
        self.attributedText = attrString
    }
}
