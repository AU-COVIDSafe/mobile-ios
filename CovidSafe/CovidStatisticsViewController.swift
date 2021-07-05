//
//  CovidStatisticsViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import Lottie

class CovidStatisticsViewController: UITableViewController {
    
    private let showHideStatisticsKey = "showHideStatisticsKey"
    
    private let heartImage = UIImage(named: "heart")
    private let virusMoleculeImage = UIImage(named: "virus-molecule")
    private let trendUpImage = UIImage(named: "trending-up")
    private let alertTriangleImage = UIImage(named: "alert-triangle")
    
    private var statisticsUpdatedDate: Date?
    private var showError: Bool = false
    private var showInternetError: Bool = false
    private var showRefresh: Bool = false
    lazy var showStatistics: Bool = {
        guard let value = UserDefaults.standard.value(forKey: showHideStatisticsKey) as? Bool else {
            return true
        }
        return value
    }(){
        didSet {
            UserDefaults.standard.set(showStatistics, forKey: showHideStatisticsKey)
        }
    }
    private lazy var statisticForStateTerritory: StateTerritory = {
        guard let value = UserDefaults.standard.string(forKey: statisticsStateTerritorySelectedKey) else {
            return StateTerritory.AU
        }
        return StateTerritory(rawValue: value)!
    }()
    
    private var statisticsData: StatisticsResponse?
    private var statisticSections: [[StatisticRowModel]] = []
    
    var statisticsDelegate: StatisticsDelegate?
    var homeDelegate: HomeDelegate?
    var contentSizeKVOToken: NSKeyValueObservation?
    
    var isLoading = false {
        didSet {
            reloadTable()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.isScrollEnabled = false
        
        tableView.register(UINib(nibName: "ExternalLinkTableViewCell", bundle: nil), forCellReuseIdentifier: "ExternalLinkTableViewCell")
        tableView.register(UINib(nibName: "StatDetailedCell", bundle: nil), forCellReuseIdentifier: "StatDetailedCell")
        tableView.register(UINib(nibName: "MainStatisticsHeader", bundle: nil), forCellReuseIdentifier: "MainStatisticsHeader")
        tableView.register(UINib(nibName: "StatisticsTableHeader", bundle: nil), forCellReuseIdentifier: "StatisticsHeader")
        tableView.register(UINib(nibName: "LoadingViewCell", bundle: nil), forCellReuseIdentifier: "LoadingViewCell")
        getStatistics()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        contentSizeKVOToken = tableView.observe(\.contentSize, options: .new) { (tableView, change) in
            if let newsize  = change.newValue {
                self.statisticsDelegate?.setStatisticsContainerHeight(height: newsize.height)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        contentSizeKVOToken?.invalidate()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?){
        if(keyPath == "contentSize"){

            if let newvalue = change?[.newKey]{
                let newsize  = newvalue as! CGSize
                statisticsDelegate?.setStatisticsContainerHeight(height: newsize.height)
            }
        }
    }
    
    // MARK: Retrieve Statistics from API
    
    func getStatistics() {
        if showStatistics {
            isLoading = true
            StatisticsAPI.getStatistics(forState: statisticForStateTerritory) { (stats, error) in
                let hasInternet = self.homeDelegate?.isInternetReachable() ?? false
                
                if error != nil {
                    switch error {
                    case .TokenExpiredError:
                        self.homeDelegate?.showTokenExpiredMessage()
                    default:
                        // do nothing special
                        break
                    }
                }
                
                self.isLoading = false
                self.setupData(statistics: stats, errorType: error, hasInternet: hasInternet)
            }
        }
    }
    
    // MARK: Process data for the table
    
    func setupData(statistics: StatisticsResponse?, errorType: CovidSafeAPIError?, hasInternet: Bool) {
        showInternetError = false
        showError = false
        showRefresh = false
        
        if errorType != nil {
            showError = true
            showRefresh = true
        }
        
        if !hasInternet {
            showInternetError = true
        }
        statisticsData = statistics
        processData(statisticsData: statisticsData, forState: statisticForStateTerritory)
        reloadTable()
    }
    
    fileprivate func processData(statisticsData: StatisticsResponse?, forState: StateTerritory) {
        statisticSections = []
        guard let statisticsData = statisticsData else {
            // this is the edge case of no data available.
            // need an empty section to render the main header
            statisticSections.append([])
            return
        }
        
        // Set updated date
        if let updatedDate = statisticsData.updatedDate {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            statisticsUpdatedDate = dateFormatter.date(from:updatedDate)
        }
        
        var mainSectionData: [StatisticRowModel] = []
        let nationalData = statisticsData.national
        
        if statisticsData.version() == 2 {
            var stateData = statisticsData.national
            switch forState {
            case .ACT:
                stateData = statisticsData.act
            case .NSW:
                stateData = statisticsData.nsw
            case .NT:
                stateData = statisticsData.nt
            case .SA:
                stateData = statisticsData.sa
            case .TAS:
                stateData = statisticsData.tas
            case .VIC:
                stateData = statisticsData.vic
            case .WA:
                stateData = statisticsData.wa
            case .QLD:
                stateData = statisticsData.qld
            default:
                stateData = statisticsData.national
            }
            
            let descriptionFormat = "%@\r\r%@"
            
            // New cases section
            let newCases = stateData?.newCases ?? 0
            let localCases = stateData?.newLocallyAcquired ?? 0
            let overseasCases = stateData?.newOverseasAcquired ?? 0
            let underInvestigation = stateData?.newUnderInvestigation ?? 0
            var bottomDesc = "\(String.localizedStringWithFormat("locally_acquired".localizedString(), "\(localCases)"))\r\(String.localizedStringWithFormat( "overseas_acquired".localizedString(), "\(overseasCases)"))\r\(String.localizedStringWithFormat( "under_investigation".localizedString(), "\(underInvestigation)"))"
            var description = String.localizedStringWithFormat(descriptionFormat, "new_cases".localizedString(), bottomDesc)
            var attributedDesc = NSMutableAttributedString(string: description)
            
            attributedDesc.addAttribute(.font,
                                        value: UIFont.preferredFont(for: .callout, weight: .semibold),
                                        range: NSRange(description.range(of: "\(localCases)")!, in: description))
            attributedDesc.addAttribute(.font,
                                        value: UIFont.preferredFont(for: .callout, weight: .semibold),
                                        range: NSRange(description.range(of: "\(overseasCases)")!, in: description))
            attributedDesc.addAttribute(.font,
                                        value: UIFont.preferredFont(for: .callout, weight: .semibold),
                                        range: NSRange(description.range(of: "\(underInvestigation)")!, in: description))
            
            mainSectionData.append(StatisticRowModel(number: newCases, description: attributedDesc, image: trendUpImage))
            
            // Active cases section
            let activeCases = stateData?.activeCases ?? 0
            let totalDeaths = stateData?.deaths ?? 0
            
            bottomDesc = String.localizedStringWithFormat("total_deaths".localizedString(), "\(totalDeaths)")
            description = String.localizedStringWithFormat(descriptionFormat, "active_cases".localizedString(), bottomDesc)
            attributedDesc = NSMutableAttributedString(string: description)
            attributedDesc.addAttribute(.font,
                                        value: UIFont.preferredFont(for: .callout, weight: .semibold),
                                        range: NSRange(description.range(of: "\(totalDeaths)")!, in: description))
            
            mainSectionData.append(StatisticRowModel(number: activeCases, description: attributedDesc, image: virusMoleculeImage))
            
            statisticSections.append(mainSectionData)
            
        } else {
            // we keep old design/data shown in case the response does not have state based data
            if let cases = nationalData?.newCases {
                mainSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "new_cases".localizedString()), image: trendUpImage))
            }

            if let cases = nationalData?.totalCases {
                mainSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "total_confirmed_cases".localizedString()), image: virusMoleculeImage))
            }

            if let cases = nationalData?.recoveredCases {
                mainSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "recovered".localizedString()), image: heartImage))
            }
            
            if let cases = nationalData?.deaths {
                mainSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "deaths".localizedString()), image: virusMoleculeImage, imageBackgroundColor: UIColor.covidSafeLightGreyColor))
            }
            
            statisticSections.append(mainSectionData)
            
            var statesSectionData: [StatisticRowModel] = []
            
            if let cases = statisticsData.act?.totalCases {
                statesSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "australian_capital_territory".localizedString())))
            }
            if let cases = statisticsData.nsw?.totalCases {
                statesSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "new_south_wales".localizedString())))
            }
            if let cases = statisticsData.nt?.totalCases {
                statesSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "northern_territory".localizedString())))
            }
            if let cases = statisticsData.qld?.totalCases {
                statesSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "queensland".localizedString())))
            }
            if let cases = statisticsData.sa?.totalCases {
                statesSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "south_australia".localizedString())))
            }
            if let cases = statisticsData.tas?.totalCases {
                statesSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "tasmania".localizedString())))
            }
            if let cases = statisticsData.vic?.totalCases {
                statesSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "victoria".localizedString())))
            }
            if let cases = statisticsData.wa?.totalCases {
                statesSectionData.append(StatisticRowModel(number: cases, description: NSAttributedString(string: "western_australia".localizedString())))
            }
            
            if statesSectionData.count > 0 {
                statisticSections.append(statesSectionData)
            }
        }
        
    }
    
    // MARK: Table view delegate
    
    fileprivate func reloadTable() {
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isLoading {
            return nil
        }
        
        if section == 0 {
            let headerView = tableView.dequeueReusableCell(withIdentifier: "MainStatisticsHeader") as! MainStatisticsHeaderViewCell
            headerView.statisticsDelegate = statisticsDelegate
            headerView.statisticsTableDelegate = self
            
            let shouldDisplayStateSelection = (statisticsData?.version() ?? 0) >= 2
            let hideShowLabel = showStatistics ? "hide".localizedString() : "show".localizedString()
            headerView.hideShowButton.setTitle(hideShowLabel, for: .normal)
            headerView.selectStateTerritoryContainer.isHidden = !showStatistics || !shouldDisplayStateSelection
            
            headerView.titleLabel.text = (statisticForStateTerritory == StateTerritory.AU || !shouldDisplayStateSelection) ? "national_numbers".localizedString() :  String.localizedStringWithFormat(
                "state_number_heading".localizedString(),
                statisticForStateTerritory.rawValue
            )
            
            if let updateDate = statisticsUpdatedDate, showStatistics {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                headerView.dateLabelContainer.isHidden = false
                headerView.dateLabelDivider.isHidden = false
                headerView.dateLabel.text = String.localizedStringWithFormat("latest_case_numbers".localizedString(), dateFormatter.string(from: updateDate))
            } else {
                headerView.dateLabelContainer.isHidden = true
                headerView.dateLabelDivider.isHidden = true
            }
            
            if showInternetError {
                headerView.errorLabel.text = "numbers_no_internet".localizedString()
            } else {
                headerView.errorLabel.text = "numbers_error".localizedString()
            }
            
            headerView.errorLabel.isHidden = !showError || !showStatistics
            headerView.refreshViewContainer.isHidden = !showRefresh || !showStatistics
            return headerView
        }
        
        if section == 1 {
            let headerView = tableView.dequeueReusableCell(withIdentifier: "StatisticsHeader")
            return headerView
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isLoading {
            return 0 // no header for section
        }
        return -1 // automatic
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        if isLoading {
            return 0 // no header for section
        }
        return 53
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if isLoading || !showStatistics {
            return 1
        }
        return statisticSections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading {
            return 1
        }
        if !showStatistics {
            return 0
        }
        return statisticSections[section].count
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let loadingCell = cell as? LoadingViewCell {
            loadingCell.stopAnimation()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        UIView.performWithoutAnimation {
            view.layoutIfNeeded()
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        UIView.performWithoutAnimation {
            cell.layoutIfNeeded()
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            let cellView = tableView.dequeueReusableCell(withIdentifier: "LoadingViewCell", for: indexPath) as! LoadingViewCell
            cellView.startAnimation()
            return cellView
        }
        
        // detailed stat row
        if indexPath.section == 0 {
            let rowData = statisticSections[indexPath.section][indexPath.row]
            if rowData.cellType == .Link {
                let cellView = tableView.dequeueReusableCell(withIdentifier: "ExternalLinkTableViewCell", for: indexPath) as! ExternalLinkTableViewCell
                
                cellView.cellImage.image = rowData.image
                cellView.linkDescription.attributedText = rowData.description
                cellView.externalLinkURL = rowData.urlLink
                
                return cellView
            } else {
                let cellView = tableView.dequeueReusableCell(withIdentifier: "StatDetailedCell", for: indexPath) as! StatDetailedViewCell
                
                cellView.statImage?.image = rowData.image
                cellView.statDescription.attributedText = rowData.description
                cellView.statNumberLabel.text = NumberFormatter.localizedString(from: NSNumber(value: rowData.number), number: .decimal)
                if #available(iOS 11.0, *) {
                    cellView.statNumberLabel.font = UIFont.preferredFont(for: .largeTitle, weight: .semibold)
                } else {
                    // Fallback on earlier versions
                    cellView.statNumberLabel.font = UIFont.preferredFont(for: .title1, weight: .semibold)
                }
                if let bkgColor = rowData.imageBackgroundColor {
                    cellView.imageBackgroundColor = bkgColor
                }
                
                return cellView
            }
        }
        
        // Simple stat row
        var cellView = tableView.dequeueReusableCell(withIdentifier: "StatSummaryCell")
        if cellView == nil {
            cellView = UITableViewCell(style: .value1, reuseIdentifier: "StatSummaryCell")
            cellView?.textLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
            cellView?.textLabel?.textColor = UIColor.covidSafeDarkFontColor
            cellView?.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
            cellView?.detailTextLabel?.textColor = UIColor.covidSafeDarkFontColor
        }
        
        let rowData = statisticSections[indexPath.section][indexPath.row]
        
        cellView!.textLabel?.attributedText = rowData.description
        cellView!.detailTextLabel?.text = NumberFormatter.localizedString(from: NSNumber(value: rowData.number), number: .decimal)
        
        return cellView!
    }
    
}

// MARK: Statistics Table Delegate Implementation

extension CovidStatisticsViewController: StatisticsTableDelegate {
    func toggleDisplayStatistics() {
        showStatistics = !showStatistics
        
        if showStatistics && statisticSections.count == 0 {
            refreshStatistics()
        } else {
            UIView.transition(with: tableView,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: { self.reloadTable() })
        }
    }
    
    func refreshStatistics() {
        getStatistics()
    }
    
    func changeStateTerritoryStatistics() {
        let selectStateTerritoryViewController = SelectableTableViewController<StateTerritory>()
        selectStateTerritoryViewController.selectedValue = statisticForStateTerritory
        selectStateTerritoryViewController.data = [[StateTerritory.AU], getStateValues()]
        selectStateTerritoryViewController.sectionTitles = ["",         "states_territories".localizedString()
]
        selectStateTerritoryViewController.delegate = self
        let navController = UINavigationController(rootViewController: selectStateTerritoryViewController)
        
        present(navController, animated: true, completion: nil)
    }
    
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
}

// MARK: Selected state territory delegate

extension CovidStatisticsViewController: TableSelectionDelegate {
    
    func didChangeSelectedValue(selectedValue: Any) {
        guard let selectedState = selectedValue as? StateTerritory else {
            return
        }
        UserDefaults.standard.set(selectedState.rawValue, forKey: statisticsStateTerritorySelectedKey)
        statisticForStateTerritory = selectedState
        getStatistics()
    }
    
}

// MARK: Table view cells

class StatDetailedViewCell: UITableViewCell {
    @IBOutlet weak var statImage: UIImageView!
    @IBOutlet weak var statNumberLabel: UILabel!
    @IBOutlet weak var statDescription: UILabel!
    @IBOutlet weak var imageContainer: UIView!
    
    var imageBackgroundColor: UIColor? {
        didSet {
            imageContainer.backgroundColor = imageBackgroundColor
        }
    }
}

class MainStatisticsHeaderViewCell: UITableViewCell {
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var dateLabelContainer: UIView!
    @IBOutlet weak var dateLabelDivider: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var refreshViewContainer: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var hideShowButton: UIButton!
    @IBOutlet weak var selectStateLabel: UILabel!
    @IBOutlet weak var selectStateTerritoryContainer: UIStackView!
    
    var statisticsDelegate: StatisticsDelegate?
    var statisticsTableDelegate: StatisticsTableDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = UIFont.preferredFont(for: .title3, weight: .semibold)
        let selectStateTerritoryTapGesture = UITapGestureRecognizer(target: self, action: #selector(selectStateTerritoryTapped))
        selectStateLabel.addGestureRecognizer(selectStateTerritoryTapGesture)
        let selectStateText = NSMutableAttributedString(string: "select_state_territory_button".localizedString(),
                                                           attributes: [.font: UIFont.preferredFont(forTextStyle: .callout),
                                                                        .underlineStyle: NSUnderlineStyle.single.rawValue])
        selectStateLabel.attributedText = selectStateText
    }
    
    @IBAction func refreshButtonTapped(_ sender: Any) {
        statisticsTableDelegate?.refreshStatistics()
    }
    
    @IBAction func showHideButtonTapped(_ sender: Any) {
        statisticsTableDelegate?.toggleDisplayStatistics()
        selectStateTerritoryContainer.isHidden = !selectStateTerritoryContainer.isHidden
    }
    
    @IBAction func selectStateTerritoryTapped(_ sender: Any) {
        statisticsTableDelegate?.changeStateTerritoryStatistics()
    }
}

class LoadingViewCell: UITableViewCell {
    
    @IBOutlet weak var loadingAnimationView: UIView!
    
    var lottieLoadingView: AnimationView?
    
    func startAnimation() {
        if lottieLoadingView == nil {
            let loadingAnimation = AnimationView(name: "Spinner_upload")
            loadingAnimation.loopMode = .loop
            loadingAnimation.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: loadingAnimationView.frame.size)
            loadingAnimationView.addSubview(loadingAnimation)
            lottieLoadingView = loadingAnimation
        }
        lottieLoadingView?.play()
    }
    
    func stopAnimation() {
        lottieLoadingView?.stop()
    }
}

// MARK: Statistics delegate

protocol StatisticsTableDelegate {
    func toggleDisplayStatistics()
    func changeStateTerritoryStatistics()
    func refreshStatistics()
}

protocol StatisticsDelegate {
    func setStatisticsContainerHeight(height: CGFloat)
}

// MARK: Statistics row model

enum StatisticCellType {
    case Link, Detail
}

struct StatisticRowModel {
    var number: Int
    var description: NSAttributedString
    var image: UIImage?
    var imageBackgroundColor: UIColor?
    var urlLink: URL?
    var cellType: StatisticCellType?
}
