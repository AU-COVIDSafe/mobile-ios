//
//  CovidStatisticsViewController.swift
//  CovidSafe
//
//  Copyright © 2020 Australian Government. All rights reserved.
//

import UIKit
import Lottie

class CovidStatisticsViewController: UITableViewController {
    
    private let heartImage = UIImage(named: "heart")
    private let virusMoleculeImage = UIImage(named: "virus-molecule")
    private let trendUpImage = UIImage(named: "trending-up")
    
    private var statisticsUpdatedDate: Date?
    private var showError: Bool = false
    private var showInternetError: Bool = false
    private var showRefresh: Bool = false
    
    private var statisticSections: [[StatisticRowModel]] = []
    
    var statisticsDelegate: StatisticsDelegate?
    
    var isLoading = false {
        didSet {
            reloadTable()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.isScrollEnabled = false
        
        tableView.register(UINib(nibName: "StatDetailedCell", bundle: nil), forCellReuseIdentifier: "StatDetailedCell")
        tableView.register(UINib(nibName: "MainStatisticsHeader", bundle: nil), forCellReuseIdentifier: "MainStatisticsHeader")
        tableView.register(UINib(nibName: "StatisticsTableHeader", bundle: nil), forCellReuseIdentifier: "StatisticsHeader")
        tableView.register(UINib(nibName: "LoadingViewCell", bundle: nil), forCellReuseIdentifier: "LoadingViewCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        tableView.removeObserver(self, forKeyPath: "contentSize")
        super.viewWillDisappear(true)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?){
        if(keyPath == "contentSize"){

            if let newvalue = change?[.newKey]{
                let newsize  = newvalue as! CGSize
                statisticsDelegate?.setStatisticsContainerHeight(height: newsize.height)
            }
        }
    }
    
    // MARK: Process data for the table
    
    func setupData(statistics: StatisticsResponse?, errorType: MessageAPIError?, hasInternet: Bool) {
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
        
        processData(statisticsData: statistics)
        reloadTable()
    }
    
    fileprivate func processData(statisticsData: StatisticsResponse?) {
        statisticSections = []
        guard let statisticsData = statisticsData else {
            // this is the edge case of no data available.
            // need an empty section to render the main header
            statisticSections.append([])
            return
        }
        let mainData = statisticsData.national
        
        // Set updated date
        if let updatedDate = statisticsData.updatedDate {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            statisticsUpdatedDate = dateFormatter.date(from:updatedDate)
        }
        
        var mainSectionData: [StatisticRowModel] = []
        
        if let cases = mainData?.newCases {
            mainSectionData.append(StatisticRowModel(number: cases, description: "new_cases".localizedString(), image: trendUpImage))
        }
        
        if let cases = mainData?.totalCases {
            mainSectionData.append(StatisticRowModel(number: cases, description: "total_confirmed_cases".localizedString(), image: virusMoleculeImage))
        }
        
        if let cases = mainData?.recoveredCases {
            mainSectionData.append(StatisticRowModel(number: cases, description: "recovered".localizedString(), image: heartImage))
        }
        
        if let cases = mainData?.deaths {
            mainSectionData.append(StatisticRowModel(number: cases, description: "deaths".localizedString(), image: virusMoleculeImage, imageBackgroundColor: UIColor.covidSafeLightGreyColor))
        }
        
        statisticSections.append(mainSectionData)
        
        var statesSectionData: [StatisticRowModel] = []
        
        if let cases = statisticsData.act?.totalCases {
            statesSectionData.append(StatisticRowModel(number: cases, description: "australian_capital_territory".localizedString()))
        }
        if let cases = statisticsData.nsw?.totalCases {
            statesSectionData.append(StatisticRowModel(number: cases, description: "new_south_wales".localizedString()))
        }
        if let cases = statisticsData.nt?.totalCases {
            statesSectionData.append(StatisticRowModel(number: cases, description: "northern_territory".localizedString()))
        }
        if let cases = statisticsData.qld?.totalCases {
            statesSectionData.append(StatisticRowModel(number: cases, description: "queensland".localizedString()))
        }
        if let cases = statisticsData.sa?.totalCases {
            statesSectionData.append(StatisticRowModel(number: cases, description: "south_australia".localizedString()))
        }
        if let cases = statisticsData.tas?.totalCases {
            statesSectionData.append(StatisticRowModel(number: cases, description: "tasmania".localizedString()))
        }
        if let cases = statisticsData.vic?.totalCases {
            statesSectionData.append(StatisticRowModel(number: cases, description: "victoria".localizedString()))
        }
        if let cases = statisticsData.wa?.totalCases {
            statesSectionData.append(StatisticRowModel(number: cases, description: "western_australia".localizedString()))
        }
        
        if statesSectionData.count > 0 {
            statisticSections.append(statesSectionData)
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
            headerView.titleLabel.font = UIFont.preferredFont(for: .title1, weight: .semibold)
            headerView.statisticsDelegate = statisticsDelegate
            
            if let updateDate = statisticsUpdatedDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy h a 'AEST'"
                headerView.dateLabel.text = dateFormatter.string(from: updateDate)
            } else {
                headerView.dateLabel.isHidden = true
            }
            
            if showInternetError {
                headerView.errorLabel.text = "numbers_no_internet".localizedString()
            } else {
                headerView.errorLabel.text = "numbers_error".localizedString()
            }
            
            headerView.errorLabel.isHidden = !showError
            headerView.refreshViewContainer.isHidden = !showRefresh
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
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if isLoading {
            return 1
        }
        return statisticSections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading {
            return 1
        }
        return statisticSections[section].count
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let loadingCell = cell as? LoadingViewCell {
            loadingCell.stopAnimation()
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
            let cellView = tableView.dequeueReusableCell(withIdentifier: "StatDetailedCell", for: indexPath) as! StatDetailedViewCell
            let rowData = statisticSections[indexPath.section][indexPath.row]
            
            cellView.statImage?.image = rowData.image
            cellView.statDescription.text = rowData.description
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
        
        cellView!.textLabel?.text = rowData.description
        cellView!.detailTextLabel?.text = NumberFormatter.localizedString(from: NSNumber(value: rowData.number), number: .decimal)
        
        return cellView!
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
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var refreshViewContainer: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    
    var statisticsDelegate: StatisticsDelegate?
    
    @IBAction func refreshButtonTapped(_ sender: Any) {
        statisticsDelegate?.refreshStatistics()
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

protocol StatisticsDelegate {
    func refreshStatistics()
    func setStatisticsContainerHeight(height: CGFloat)
}

// MARK: Statistics row model

struct StatisticRowModel {
    var number: Int
    var description: String
    var image: UIImage?
    var imageBackgroundColor: UIColor?
}
