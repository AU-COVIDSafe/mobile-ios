//
//  SelectStateTerritoryViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

let statisticsStateTerritorySelectedKey = "statisticsStateTerritorySelectedKey"

class SelectStateTerritoryViewController: UITableViewController {
    
    var delegate: StateTerritorySelectionDelegate?
    
    lazy var stateTerritoryConfig: StateTerritory = {
        guard let value = UserDefaults.standard.string(forKey: statisticsStateTerritorySelectedKey) else {
            return StateTerritory.AU
        }
        return StateTerritory(rawValue: value)!
    }(){
        didSet {
            UserDefaults.standard.set(stateTerritoryConfig.rawValue, forKey: statisticsStateTerritorySelectedKey)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "select_state_territory_heading".localizedString()
        tableView.isScrollEnabled = false
        
        let buttonTitle = "global_cancel_button_title".localizedString()

        let item = UIBarButtonItem(
          title: buttonTitle,
          style: .plain,
          target: self,
          action: #selector(dismissView)
        )
        item.tintColor = .covidSafeColor
        
        navigationItem.rightBarButtonItem = item
        
        tableView.register(UINib(nibName: "StateTerritoryTableViewCell", bundle: nil), forCellReuseIdentifier: "StateTerritoryCell")
    }
    
    @objc func dismissView() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return 8
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StateTerritoryCell", for: indexPath) as! StateTerritoryTableViewCell

        // Configure the cell...
        if indexPath.section == 0 {
            cell.stateTerritoryLabel.text = "country_region_name_au".localizedString()
            cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.AU
        } else {
            switch indexPath.row {
            case 0:
                cell.stateTerritoryLabel.text = "australian_capital_territory".localizedString()
                cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.ACT
            case 1:
                cell.stateTerritoryLabel.text = "new_south_wales".localizedString()
                cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.NSW
            case 2:
                cell.stateTerritoryLabel.text = "northern_territory".localizedString()
                cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.NT
            case 3:
                cell.stateTerritoryLabel.text = "queensland".localizedString()
                cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.QLD
            case 4:
                cell.stateTerritoryLabel.text = "south_australia".localizedString()
                cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.SA
            case 5:
                cell.stateTerritoryLabel.text = "tasmania".localizedString()
                cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.TAS
            case 6:
                cell.stateTerritoryLabel.text = "victoria".localizedString()
                cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.VIC
            case 7:
                cell.stateTerritoryLabel.text = "western_australia".localizedString()
                cell.isSelectedTickView.isHidden = stateTerritoryConfig != StateTerritory.WA
            default:
                cell.stateTerritoryLabel.text = ""
                cell.setSelected(false, animated: false)
            }
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }
        
        return "states_territories".localizedString()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            stateTerritoryConfig = StateTerritory.AU
        } else {
            switch indexPath.row {
            case 0:
                stateTerritoryConfig = StateTerritory.ACT
            case 1:
                stateTerritoryConfig = StateTerritory.NSW
            case 2:
                stateTerritoryConfig = StateTerritory.NT
            case 3:
                stateTerritoryConfig = StateTerritory.QLD
            case 4:
                stateTerritoryConfig = StateTerritory.SA
            case 5:
                stateTerritoryConfig = StateTerritory.TAS
            case 6:
                stateTerritoryConfig = StateTerritory.VIC
            case 7:
                stateTerritoryConfig = StateTerritory.WA
            default:
                stateTerritoryConfig = StateTerritory.AU
            }
        }
        delegate?.didChangeStateTerritory(selectedState: stateTerritoryConfig)
        dismissView()
    }
}

enum StateTerritory: String {
    case AU, ACT, NSW, NT, QLD, SA, TAS, VIC, WA
}

protocol StateTerritorySelectionDelegate {
    func didChangeStateTerritory( selectedState: StateTerritory )
}
