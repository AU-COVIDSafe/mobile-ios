//
//  RestrictionTableViewController.swift
//  CovidSafe
//
//  Copyright © 2021 Australian Government. All rights reserved.
//

import UIKit

let restrictionSelectedStateKey = "restrictionSelectedStateKey"
let restrictionSelectedActivityKey = "restrictionSelectedActivityKey"

class RestrictionTableViewController: UITableViewController {
    
    @IBOutlet var tableFooterView: UIView!
    
    lazy var restrictionSelectedState: StateTerritory = {
        guard let value = UserDefaults.standard.value(forKey: restrictionSelectedStateKey) as? String else {
            return StateTerritory.AU
        }
        return StateTerritory(rawValue: value)!
    }(){
        didSet {
            UserDefaults.standard.set(restrictionSelectedState.rawValue, forKey: restrictionSelectedStateKey)
        }
    }
    
    lazy var restrictionSelectedActivity: JurisdictionalRestrictionActivity? = {
        guard let value = UserDefaults.standard.value(forKey: restrictionSelectedActivityKey) as? String, !value.isEmpty else {
            return nil
        }
        return value
    }(){
        didSet {
            UserDefaults.standard.set(restrictionSelectedActivity, forKey: restrictionSelectedActivityKey)
        }
    }
    
    var stateRestrictions: StateRestriction?
    
    var jurisdictionalRestrictionActivities: [JurisdictionalRestrictionActivity] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: "SimpleTableViewCell", bundle: nil), forCellReuseIdentifier: "SimpleTableCell")
        tableView.register(UINib(nibName: "SelectionTableViewCell", bundle: nil), forCellReuseIdentifier: "SelectionTableCell")
        tableView.register(UINib(nibName: "TableSectionHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "SectionHeader")
        
        // call api if needed
        if restrictionSelectedState != .AU {
            getRestrictions(shouldFetchFromApi: true)
        } else {
            setupTableFooter()
        }
    }

    // MARK: - Table view data source
    
    func reloadTableView() {
        setupTableFooter()
        tableView.reloadData()
    }
    
    func setupTableFooter() {
        tableView.tableFooterView = restrictionSelectedState == .AU || restrictionSelectedActivity == nil ? tableFooterView : nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if restrictionSelectedState != .AU && restrictionSelectedActivity != nil {
            // top section for selection, bottom for data from restrictions API
            return 2
        }
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            return restrictionSelectedState == .AU ? 1 : 2
        } else {
            if let selectedActivity = restrictionSelectedActivity,
               let activities = stateRestrictions?.activities {
                
                let activity = activities.first { (activity) -> Bool in
                    return activity.activityTitle == selectedActivity
                }
                
                let hasMainContent = activity?.mainContent != nil && !(activity?.mainContent?.isEmpty ?? true)
                let includeMainContent = hasMainContent ? 1 : 0
                return (activity?.sections?.count ?? 0) + includeMainContent
            }
            return 0
        }
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            // check if value is present
            let isValueEmpty = indexPath.row == 0 ? restrictionSelectedState == .AU : restrictionSelectedActivity?.isEmpty ?? true
            
            if isValueEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SimpleTableCell") as! SimpleTableViewCell
                cell.title.textColor = UIColor.covidSafeColor
                cell.rightImageView.image = UIImage(named: "chevron-right-green")
                cell.rightImageView.isHidden = true
                configureSimpleCell(cell: cell, row: indexPath.row)
                cell.selectionStyle = .none
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SelectionTableCell") as! SelectionTableViewCell
                configureSelectionCell(cell: cell, row: indexPath.row)
                cell.selectionStyle = .none
                return cell
            }
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SimpleTableCell") as! SimpleTableViewCell
        cell.title.textColor = UIColor.covidSafeDarkFontColor
        cell.rightImageView.image = UIImage(named: "ChevronRight")
        cell.rightImageView.isHidden = false
        
        cell.title.text = ""
        if let selectedActivity = restrictionSelectedActivity {
            cell.title.text = getSectionTitle(for: selectedActivity, indexPath: indexPath)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            let sectionHeaderView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! SectionHeaderView
            
            guard let selectedActivity = restrictionSelectedActivity, let activity = getActivity(activityName: selectedActivity) else {
                sectionHeaderView.title.text = ""
                return sectionHeaderView
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            sectionHeaderView.title.text = activity.dateUpdated
            return sectionHeaderView
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            // returning nil does not suffice
            return 0
        } else {
            // automatic
            return -1
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 1 {
            // if should show content
            let contentView = RestrictionDetailsViewController(nibName: "RestrictionsView", bundle: nil)
            contentView.hideSubtitle = false
            contentView.hideBackButton = false
            
            contentView.titleString = ""
            contentView.subtitleString = ""
            contentView.htmlString = ""
            if let selectedActivity = restrictionSelectedActivity {
                contentView.titleString = getSectionTitle(for: selectedActivity, indexPath: indexPath)
                contentView.subtitleString = getSectionSubtitle(for: indexPath)
                contentView.htmlString = getSectionHtmlContent(for: selectedActivity, indexPath: indexPath)
            }
            navigationController?.pushViewController(contentView, animated: true)
            
            return
        }
        
        var tableViewController: UITableViewController!
        
        if indexPath.row == 0 {
            // bring up state selections
            let selectStateTerritoryViewController = SelectableTableViewController<StateTerritory>()
            selectStateTerritoryViewController.title = "restrictions_select_state".localizedString()
            selectStateTerritoryViewController.selectedValue = restrictionSelectedState
            selectStateTerritoryViewController.data = [getStateValues()]
            selectStateTerritoryViewController.delegate = self
            
            tableViewController = selectStateTerritoryViewController
            
        } else if indexPath.row == 1 {
            // bring up activity selections
            let selectActivityyViewController = SelectableTableViewController<JurisdictionalRestrictionActivity>()
            selectActivityyViewController.title = "restrictions_select_activity".localizedString()
            selectActivityyViewController.selectedValue = restrictionSelectedActivity
            selectActivityyViewController.data = [jurisdictionalRestrictionActivities]
            selectActivityyViewController.delegate = self
            
            tableViewController = selectActivityyViewController
        }
        
        let navController = UINavigationController(rootViewController: tableViewController)
        present(navController, animated: true, completion: nil)
    }
    
    func configureSimpleCell(cell: SimpleTableViewCell, row: Int) {
        if row == 0 {
            cell.title.text = "restrictions_select_state".localizedString()
        } else {
            cell.title.text = "restrictions_select_activity".localizedString()
        }
    }
    
    func configureSelectionCell(cell: SelectionTableViewCell, row: Int) {
                
        if row == 0 {
            cell.title.text = "restrictions_state".localizedString()
            cell.selection.text = restrictionSelectedState.stateTerritoryFullName()
        } else {
            cell.selection.text = restrictionSelectedActivity
            cell.title.text = "restrictions_activity".localizedString()
        }
    }
    
    //MARK: selectable options
    
    func getStateValues() -> [StateTerritory] {
        return [StateTerritory.ACT,
                StateTerritory.NSW,
                StateTerritory.NT,
                StateTerritory.QLD,
                StateTerritory.SA,
                StateTerritory.TAS,
                StateTerritory.VIC,
                StateTerritory.WA]
    }
    
    //MARK: data retrieval
    
    fileprivate func getSectionTitle(for selectedActivity: JurisdictionalRestrictionActivity, indexPath: IndexPath) -> String {
        guard let activity = getActivity(activityName: selectedActivity) else {
            return ""
        }
        let hasMainContent = activity.mainContent != nil && !activity.mainContent!.isEmpty
        if hasMainContent && indexPath.row == 0 {
            return "main_restrictions".localizedString()
        }
        
        let indexOffset = hasMainContent ? -1 : 0
        guard let activitySections = activity.sections,
              activitySections.count > (indexPath.row + indexOffset) else {
            return ""
        }
        return activitySections[indexPath.row + indexOffset].title ?? ""
        
    }
    
    fileprivate func getSectionHtmlContent(for selectedActivity: JurisdictionalRestrictionActivity, indexPath: IndexPath) -> String? {
        guard let activity = getActivity(activityName: selectedActivity) else {
            return nil
        }
        let hasMainContent = activity.mainContent != nil && !activity.mainContent!.isEmpty
        if hasMainContent && indexPath.row == 0 {
            return activity.mainContent
        }
        
        let indexOffset = hasMainContent ? -1 : 0
        guard let activitySections = activity.sections,
              activitySections.count > (indexPath.row + indexOffset) else {
            return nil
        }
        return activitySections[indexPath.row + indexOffset].content ?? nil
       
    }
    
    fileprivate func getSectionSubtitle(for indexPath: IndexPath) -> String {
        return "\(restrictionSelectedState.rawValue) - \(restrictionSelectedActivity ?? "")"
    }
    
    fileprivate func getActivity(activityName: JurisdictionalRestrictionActivity) -> RestrictionsActivity? {
        
        if let activities = stateRestrictions?.activities {
            
            let activity = activities.first { (activity) -> Bool in
                return activity.activityTitle == activityName
            }
            
            return activity
        }
        
        return nil
    }
}

// MARK: Selected state territory delegate

extension RestrictionTableViewController: TableSelectionDelegate {
        
    func didChangeSelectedValue(selectedValue: Any) {
        var didChangeState = false
        if let value = selectedValue as? StateTerritory  {
            didChangeState = restrictionSelectedState != value
            restrictionSelectedState = value
            restrictionSelectedActivity = nil
        }
        
        if let value = selectedValue as? JurisdictionalRestrictionActivity  {
            restrictionSelectedActivity = value
        }
        getRestrictions(shouldFetchFromApi: didChangeState || stateRestrictions == nil)
    }
    
}

extension RestrictionTableViewController {
    
    fileprivate func getRestrictions(shouldFetchFromApi: Bool) {
        guard restrictionSelectedState != .AU, shouldFetchFromApi else {
            // reload to reflect selections in the table
            reloadTableView()
            return
        }
        
        // call API
        RestrictionsAPI.getRestrictions(forState: restrictionSelectedState) { (restrictionsResponse, error) in
            guard error == nil else {
                // handle api error
                let errorVC = CSGenericErrorViewController(nibName: "CSGenericErrorView", bundle: nil)
                errorVC.errorViewModel =
                    CSGenericErrorViewModel(errorTitle: "restrictions_error_heading".localizedString(),
                                            errorContentDescription: "restrictions_error_message".localizedString(),
                                            mainButtonLabel: "restrictions_error_try".localizedString(),
                                            mainButtonCallback: {
                                                self.getRestrictions(shouldFetchFromApi: true)
                                            },
                                            secondaryButtonLabel: "restrictions_error_dismiss".localizedString(),
                                            secondaryButtonCallback: nil)
                self.present(errorVC, animated: true, completion: nil)
                return
            }
            
            self.stateRestrictions = restrictionsResponse
            self.retrieveActivities()
            self.reloadTableView()
        }
    }
    
    fileprivate func retrieveActivities() {
        guard let restrictions = stateRestrictions, let activities = restrictions.activities else {
            return
        }
        jurisdictionalRestrictionActivities = []
        for activity in activities {
            if let activityName = activity.activityTitle {
                jurisdictionalRestrictionActivities.append(activityName)
            }
        }
    }
}

class SimpleTableViewCell: UITableViewCell {
    
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var rightImageView: UIImageView!
}

class SelectionTableViewCell: UITableViewCell {
    
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var selection: UILabel!
}

class SectionHeaderView: UITableViewHeaderFooterView {
    
    @IBOutlet weak var title: UILabel!
}
