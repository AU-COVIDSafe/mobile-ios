//
//  StateTerritoryTableViewCell.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

class StateTerritoryTableViewCell: UITableViewCell {

    @IBOutlet weak var stateTerritoryLabel: UILabel!
    @IBOutlet weak var isSelectedTickView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        resetCell()
    }
    
    func resetCell() {
        isSelectedTickView.isHidden = true
    }
    
}
