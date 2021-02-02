//  Copyright © 2020 Australian Government All rights reserved.

import UIKit

final class UploadDataErrorViewController: UIViewController {
    
    var uploadErrorMessage: String = ""
    
    @IBOutlet weak var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        errorLabel.text = String.localizedStringWithFormat("dialog_error_uploading_message".localizedString(), uploadErrorMessage)
    }
    
    @IBAction func onBackTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
