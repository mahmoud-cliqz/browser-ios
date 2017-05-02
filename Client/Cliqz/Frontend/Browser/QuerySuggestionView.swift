//
//  QuerySuggestionView.swift
//  Client
//
//  Created by Mahmoud Adam on 1/2/17.
//  Copyright © 2017 Mozilla. All rights reserved.
//

import UIKit
protocol QuerySuggestionDelegate : class {
    func autoComplete(suggestion: String)
}

class QuerySuggestionView: UIView {
    
    //MARK:- Constants
    private let kViewHeight: CGFloat = 44
    private let scrollView = UIScrollView()
    private let boldFontAttributes = [NSFontAttributeName: UIFont.boldSystemFontOfSize(17), NSForegroundColorAttributeName: UIColor.whiteColor()]
    private let normalFontAttributes = [NSFontAttributeName: UIFont.systemFontOfSize(16), NSForegroundColorAttributeName: UIColor.whiteColor()]
    private let bgColor = UIColor(rgb: 0xADB5BD)
    private let separatorBgColor = UIColor(rgb: 0xC7CBD3)
    private let margin: CGFloat = 10
    
    //MARK:- instance variables
    weak var delegate : QuerySuggestionDelegate? = nil
    private var currentQuery: String = ""
    private var currentSuggestions: [String] = []
    
    
    init() {
        let screenBounds = UIScreen.mainScreen().bounds
        let frame = CGRectMake(0.0, 0.0, CGRectGetWidth(screenBounds), kViewHeight);
        
        super.init(frame: frame)
        self.autoresizingMask = .FlexibleWidth
        self.backgroundColor = bgColor
        
        scrollView.frame = frame
        self.addSubview(self.scrollView)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector:  #selector(QuerySuggestionView.viewRotated), name: UIDeviceOrientationDidChangeNotification, object: nil)
        
        if !QuerySuggestions.isEnabled() {
            self.hidden = true
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector:#selector(showSuggestions(_:)) , name: QuerySuggestions.ShowSuggestionsNotification, object: nil)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func showSuggestions(notification: NSNotification) {
        if let suggestionsData = notification.object as? [String: AnyObject],
                query = suggestionsData["query"] as? String,
                suggestions = suggestionsData["suggestions"] as? [String] {
            clearSuggestions()
            showSuggestions(query, suggestions: suggestions)
        }
    }
    
    func clearSuggestions() {
        let subViews = scrollView.subviews
        for subView in subViews {
            subView.removeFromSuperview()
        }
    }
    /*
     self?.clearSuggestions()
     self?.showSuggestions(query, suggestions: suggestions)
     */
    //MARK:- Helper methods
    
    
    private func showSuggestions(query: String, suggestions: [String]) {
        currentQuery = query
        currentSuggestions = suggestions
        
        var index = 0
        var x: CGFloat = margin
        var difference:CGFloat = 0
        var offset:CGFloat = 0
        var displayedSuggestions = [(String, CGFloat)]()
        
        // Calcuate extra space after the last suggesion
        for suggestion in suggestions {
            if suggestion.trim() == query.trim() {
                continue
            }
            let suggestionWidth = getWidth(suggestion)
            // show Max 3 suggestions which does not exceed screen width
            if x + suggestionWidth > self.frame.width || index > 2 {
                break;
            }
            // increment step
            x = x + suggestionWidth + 2*margin + 1
            index = index + 1
            displayedSuggestions.append((suggestion, suggestionWidth))
        }
        
        // distribute the extra space evenly on all suggestions
        difference = self.frame.width - x
        offset = round(difference/CGFloat(index))
        
        // draw the suggestions inside the view
        x = margin
        index = 0
        for (suggestion, width) in displayedSuggestions {
            let suggestionWidth = width + offset
            // Adding vertical separator between suggestions
            if index > 0 {
                let verticalSeparator = createVerticalSeparator(x)
                scrollView.addSubview(verticalSeparator)
            }
            // Adding the suggestion button
            let suggestionButton = createSuggestionButton(x, index: index, suggestion: suggestion, suggestionWidth: suggestionWidth)
            scrollView.addSubview(suggestionButton)
            
            // increment step
            x = x + suggestionWidth + 2*margin + 1
            index = index + 1
        }
        
        let availableCount = suggestions.count > 3 ? 3 : suggestions.count
        let customData = ["qs_show_count" : displayedSuggestions.count, "qs_available_count" : availableCount]
        TelemetryLogger.sharedInstance.logEvent(.QuerySuggestions("show", customData))
    }
    
    private func getWidth(suggestion: String) -> CGFloat {
        let sizeOfString = (suggestion as NSString).sizeWithAttributes(boldFontAttributes)
        return sizeOfString.width + 5
    }

    private func createVerticalSeparator(x: CGFloat) -> UIView {
        let verticalSeparator = UIView()
        verticalSeparator.frame = CGRectMake(x-11, 0, 1, kViewHeight)
        verticalSeparator.backgroundColor = separatorBgColor
        return verticalSeparator;
    }
    
    private func createSuggestionButton(x: CGFloat, index: Int, suggestion: String, suggestionWidth: CGFloat) -> UIButton {
        let button = UIButton(type: .Custom)
        let suggestionTitle = getTitle(suggestion)
        button.setAttributedTitle(suggestionTitle, forState: .Normal)
        button.frame = CGRectMake(x, 0, suggestionWidth, kViewHeight)
        button.addTarget(self, action: #selector(selectSuggestion(_:)), forControlEvents: .TouchUpInside)
        button.tag = index
        return button
    }
    
    private func getTitle(suggestion: String) -> NSAttributedString {
        
        let prefix = currentQuery
        var title: NSMutableAttributedString!
        
        if let range = suggestion.rangeOfString(prefix) where range.startIndex == suggestion.startIndex {
            title = NSMutableAttributedString(string:prefix, attributes:normalFontAttributes)
            var suffix = suggestion
            suffix.replaceRange(range, with: "")
            title.appendAttributedString(NSAttributedString(string: suffix, attributes:boldFontAttributes))
            
        } else {
            title = NSMutableAttributedString(string:suggestion, attributes:boldFontAttributes)
        }
        return title
    }
    
    @objc private func selectSuggestion(button: UIButton) {
        
        guard let suggestion = button.titleLabel?.text else {
            return
        }
        delegate?.autoComplete(suggestion + " ")
        
        let customData = ["index" : button.tag]
        TelemetryLogger.sharedInstance.logEvent(.QuerySuggestions("click", customData))
    }
    
    @objc private func viewRotated() {
        guard QuerySuggestions.isEnabled() else {
            self.hidden = true
            return
        }
        
        clearSuggestions()
        if OrientationUtil.isPortrait() {
            self.hidden = false
            self.showSuggestions(currentQuery, suggestions: currentSuggestions)
        } else {
            self.hidden = true
        }
        
    }
}
