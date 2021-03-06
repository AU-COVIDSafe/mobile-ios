//
//  SelectStateTerritoryViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit

let statisticsStateTerritorySelectedKey = "statisticsStateTerritorySelectedKey"

class SelectableTableViewController<T>: UITableViewController where T:SimpleCellObject {
    
    var delegate: TableSelectionDelegate?
    
    var selectedValue: T?
    var data:[[T]] = []
    var sectionTitles: [String] = []
    
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
    
    fileprivate func getNumberOfSections() -> Int {
        return data.count
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return getNumberOfSections()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data[section].count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StateTerritoryCell", for: indexPath) as! StateTerritoryTableViewCell

        // Configure the cell...
        let sectionValues = data[indexPath.section]
        let rowValue = sectionValues[indexPath.row]
        
        cell.stateTerritoryLabel.text = rowValue.getCellTitle()
        cell.isSelectedTickView.isHidden = selectedValue?.getCellTitle() != rowValue.getCellTitle()

        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sectionTitles.count > section {
            return sectionTitles[section]
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let sectionValues = data[indexPath.section]
        let selectedValue = sectionValues[indexPath.row]
        
        delegate?.didChangeSelectedValue(selectedValue: selectedValue)
        dismissView()
    }
}

protocol SimpleCellObject {
    func getCellTitle() -> String
}

enum StateTerritory: String {
    case AU, ACT, NSW, NT, QLD, SA, TAS, VIC, WA
}

extension StateTerritory {
    
    func stateTerritoryFullName() -> String {
        switch self {
        case .ACT:
            return "australian_capital_territory".localizedString()
        case .NSW:
            return "new_south_wales".localizedString()
        case .NT:
            return "northern_territory".localizedString()
        case .QLD:
            return "queensland".localizedString()
        case .SA:
            return "south_australia".localizedString()
        case .TAS:
            return "tasmania".localizedString()
        case .VIC:
            return "victoria".localizedString()
        case .WA:
            return "western_australia".localizedString()
        default:
            return "country_region_name_au".localizedString()

        }
    }
}

extension StateTerritory: SimpleCellObject {
    
    func getCellTitle() -> String {
        return stateTerritoryFullName()
    }
}

protocol TableSelectionDelegate {
    func didChangeSelectedValue( selectedValue: Any )
}
