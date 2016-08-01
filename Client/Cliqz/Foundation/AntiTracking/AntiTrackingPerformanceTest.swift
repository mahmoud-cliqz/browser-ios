//
//  AntiTrackingPerformanceTest.swift
//  Client
//
//  Created by Mahmoud Adam on 7/27/16.
//  Copyright © 2016 Mozilla. All rights reserved.
//

import Foundation

class AntiTrackingPerformanceTest: NSObject {
    
    private var browserViewController: BrowserViewController?
    private var topURLs = [String]()
    private var nextUrlIndex = -1
    private var startTimeStamp = 0.0
    private var statisticCSV = ""
    
    //MARK: - Singltone
    static let sharedInstance = AntiTrackingPerformanceTest()
    
    func startTest(browserViewController: BrowserViewController) {
        guard let topURLs = loadTopURLs() else {
            return
        }
        self.topURLs = topURLs
        browserViewController.urlBar.leaveOverlayMode()
        
        self.browserViewController = browserViewController
        loadNextUrl()
        
        
    }
    func urlFinishedLoading() {
        guard nextUrlIndex >= 0 else {
            return
        }
        let finishTimeStamp = NSDate.getCurrentMillis()
        let numberOfPassedRequests = AntiTrackingModule.sharedInstance.numberOfPassedRequests
        let numberOfModifiedRequests = AntiTrackingModule.sharedInstance.numberOfModifiedRequests
        AntiTrackingModule.sharedInstance.resetStatistics()
        let url = topURLs[nextUrlIndex]
        
        saveStatisticRecord(url, startTimeStamp: startTimeStamp, finishTimeStamp: finishTimeStamp, numberOfPassedRequests: numberOfPassedRequests, numberOfModifiedRequests: numberOfModifiedRequests)
        
        
        loadNextUrl()
    }
    
    private func loadNextUrl() {
        nextUrlIndex += 1
        guard topURLs.count > nextUrlIndex else {
            exportStatistics()
            return
        }
        
        let nextUrl = NSURL(string: topURLs[nextUrlIndex])!
        
        startTimeStamp = NSDate.getCurrentMillis()
        browserViewController!.navigateToURL(nextUrl)
    }
    
    private func loadTopURLs() -> [String]? {
        guard let path = NSBundle.mainBundle().pathForResource("topUrls", ofType: "plist") else {
            return nil
        }
        
        return NSArray(contentsOfFile: path) as? [String]
    }
    
    private func saveStatisticRecord(url: String,startTimeStamp: Double, finishTimeStamp: Double, numberOfPassedRequests: Int, numberOfModifiedRequests: Int) {
        statisticCSV += "\(url), \(startTimeStamp), \(finishTimeStamp), \(numberOfPassedRequests), \(numberOfModifiedRequests)\n"
    }
    
    private func exportStatistics() {
        
    }
}
