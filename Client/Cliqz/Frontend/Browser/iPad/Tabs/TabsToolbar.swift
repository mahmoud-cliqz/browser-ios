//
//  TabsToolbar.swift
//  Client
//
//  Created by Mahmoud Adam on 8/23/17.
//  Created based on https://github.com/graetzer/SGTabs for Objective C
//

import UIKit

struct TabsToolbarUX {
    
    static let kAddTabDuration = 0.3
    static let kRemoveTabDuration = 0.3
    static let kTabsToolbarHeigth = CGFloat(10.0)
    static let kTabsToolbarHeigthFull = CGFloat(44.0)
    static let kTabsHeigth = CGFloat(35.0)
    static let kTabsBottomMargin = CGFloat(1.0)
    static let kAddButtonWidth = CGFloat(40.0)
    static let kCornerRadius = CGFloat(6.5)
    static let kShadowRadius = CGFloat(5.0)
    
    static let kTabColor = UIColor.init(red: 208.0/255.0, green: 212.0/255.0, blue: 225.0/255.0, alpha: 1.0)
    static let kTabDarkerColor = UIColor.init(red: 138.0/255.0, green: 142.0/255.0, blue: 155.0/255.0, alpha: 1.0)
    static let kTabBackgroundColor = UIColor.init(red: 113.0/255.0, green: 118.0/255.0, blue: 120.0/255.0, alpha: 1.0)
}

class TabsToolbar: UIView {
    private weak var tabManager: TabManager!
    private var tabsViews = [TabView]()
    fileprivate var selectedTabIndex = 0
    
    
    // MARK: - initialization
    init(frame: CGRect, tabManager: TabManager) {
        super.init(frame: frame)
        self.tabManager = tabManager
        tabManager.addDelegate(self)
        
        self.backgroundColor = TabsToolbarUX.kTabBackgroundColor
        self.isOpaque = false
        self.autoresizingMask = .flexibleWidth
        self.autoresizesSubviews = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Drawing
    override func layoutSubviews () {
        self.resizeTabs()
    }
    
    // MARK: - Tab operations
    
    func addTab(_ tab: Tab) {
        let width = self.tabWidth(self.tabsViews.count + 1)
        let tabsBottomMargin = TabsToolbarUX.kTabsBottomMargin
        
        // Float the subview in from right
        let frame = CGRect(x: self.bounds.size.width, y: 0, width: width, height: self.bounds.size.height - tabsBottomMargin)
        let newTab = TabView(frame: frame, tab: tab)
        newTab.closeButton.isHidden = true
        
        // Setup gesture recognizers
        let tapGuesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGuesture.numberOfTapsRequired = 1
        tapGuesture.numberOfTouchesRequired = 1
        tapGuesture.delegate = self
        newTab.addGestureRecognizer(tapGuesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        newTab.addGestureRecognizer(panGesture)
        
        // Setup close button
        newTab.closeButton.addTarget(self, action: #selector(handleRemove(_:)), for: .touchUpInside)
        
        // Add the tab
        self.tabsViews.append(newTab)
        self.addSubview(newTab)
        
        
        for i in 0..<self.tabsViews.count {
            let tab = self.tabsViews[i]
            // By setting the real position after the view is added, we create a float from rigth transition
            tab.frame = CGRect(x: width * CGFloat(i), y: 0, width: width, height: self.bounds.size.height - tabsBottomMargin)
            tab.setNeedsDisplay()
        }
        if selectedTabIndex < tabsViews.count {
            self.bringSubview(toFront: tabsViews[selectedTabIndex])
        }
        
    }
    
    func removeTab(_ tab: Tab) {
        guard let index = indexOfTab(tab) else { return }
        
        self.removeTab(atIndex: index)
    }
    
    func removeTab(atIndex index: Int) {
        let oldTab = self.tabsViews[index]
        oldTab.removeFromSuperview()
        
        self.tabsViews.remove(at:index)
        self.resizeTabs()
    }
    
    func selectTab(_ tab: Tab?) {
        guard let index = indexOfTab(tab) else { return }
        
        selectTab(atIndex: index)
    }

    func selectTab(atIndex index: Int) {
        guard index < self.tabsViews.count else { return }
        selectedTabIndex = index
        
        for i in 0..<self.tabsViews.count {
            let tabView = self.tabsViews[i]
            if i == index {
                tabView.closeButton.isHidden = false
                tabView.selected = true
                self.bringSubview(toFront: tabView)
            } else {
                tabView.closeButton.isHidden = true
                tabView.selected = false
            }
            tabView.setNeedsDisplay()
        }
        
    }
    
    func refreshSelectedTabTitle() {
        guard selectedTabIndex < self.tabsViews.count else { return }
        tabsViews[selectedTabIndex].updateTabTitle()
    }
    
    func indexOfTab(_ tab: Tab?) -> Int? {
        guard let tab = tab else { return nil }
        
        for i in 0..<self.tabsViews.count {
            let tabView = self.tabsViews[i]
            if tabView.tab == tab {
                return i;
            }
        }
        return nil
    }
    
    func tabAtIndex(_ index: Int) -> Tab? {
        guard index < self.tabsViews.count else { return nil }
        
        return self.tabsViews[index].tab
    }

    // MARK: - Actions
    @objc fileprivate func handleRemove(_ sender: Any) {
        if let view = sender as? UIView,
            let tabView = view.superview as? TabView {
            tabManager.removeTab(tabView.tab)
        }
    }
    
    @objc fileprivate func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if let tabView = gestureRecognizer.view as? TabView, gestureRecognizer.state == .ended {
            tabManager.selectTab(tabView.tab)
        }
    }
    
    @objc fileprivate func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let panTabView = gestureRecognizer.view as? TabView,
            let panPosition = self.tabsViews.index(of: panTabView) else {
                return
        }
        
        
        if (gestureRecognizer.state == .began) {
            tabManager.selectTab(panTabView.tab)
            
        } else if (gestureRecognizer.state == .changed) {
            let position = gestureRecognizer.translation(in: self)
            let center = CGPoint(x: panTabView.center.x + position.x,
                                 y: panTabView.center.y)
        
            // Don't move the tab out of the view
            if center.x < self.bounds.size.width && center.x > 0 {
                panTabView.center = center;
                gestureRecognizer.setTranslation(CGPoint.zero, in: self)
                
                let width = self.tabWidth(self.tabsViews.count)
                // If more than half the tab width is moved, switch the positions
                let halfTab = center.x - width * CGFloat(panPosition) - width / CGFloat(2)
                if abs(halfTab) > width/2 {
                    let nextPos = position.x > 0 ? panPosition+1 : panPosition-1;
                    if nextPos >= self.tabsViews.count { return }
                    
                    let nextTabView = self.tabsViews[nextPos]
                    if selectedTabIndex == panPosition {
                        selectedTabIndex = nextPos;
                    }
                    
                    swap(&self.tabsViews[panPosition], &self.tabsViews[nextPos])
                    tabManager.swapTabs(oldTabIndex: panPosition, newTabIndex: nextPos)
                    
                    tabManager.selectTab(panTabView.tab)
                    
                    
                    UIView.animate(withDuration: 0.5, animations: {
                        nextTabView.frame = CGRect(x: width * CGFloat(panPosition), y: 0, width: width, height: self.bounds.size.height - TabsToolbarUX.kTabsBottomMargin)
                    })
                }
            }
        } else if (gestureRecognizer.state == .ended) {
            let velocity = gestureRecognizer.velocity(in: self)
            UIView.animate(withDuration: 0.5, animations: { [weak self] in
                panTabView.center = CGPoint(x: panTabView.center.x + velocity.x * 0.025,
                                            y: panTabView.center.y)
                self?.resizeTabs()
            })
        }
    }


    // MARK: - Private helper methods
    
    private func resizeTabs() {
        let width = self.tabWidth(self.tabsViews.count)
        let bottomMargin = TabsToolbarUX.kTabsBottomMargin
        for i in 0..<self.tabsViews.count {
            let tabView = self.tabsViews[i]
            tabView.frame = CGRect(x: width*CGFloat(i), y: 0, width: width, height: self.bounds.size.height - bottomMargin)
        }
    }
    
    private func tabWidth(_ count: Int) -> CGFloat {
        if count > 0 {
            return self.bounds.size.width/CGFloat(count)
        } else {
            return self.bounds.size.width
        }
    }

}

extension TabsToolbar : UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}


extension TabsToolbar : TabManagerDelegate {
    func tabManager(_ tabManager: TabManager, didSelectedTabChange selected: Tab?, previous: Tab?) {
        self.selectTab(selected)
    }
    
    func tabManager(_ tabManager: TabManager, didCreateTab tab: Tab) {
        
    }
    
    func tabManager(_ tabManager: TabManager, didAddTab tab: Tab) {
        self.addTab(tab)
    }
    
    func tabManager(_ tabManager: TabManager, didRemoveTab tab: Tab, removeIndex: Int) {
        self.removeTab(tab)
    }
    
    func tabManagerDidRestoreTabs(_ tabManager: TabManager) {
        //TODO: Review
    }
    
    func tabManagerDidAddTabs(_ tabManager: TabManager) {

    }
    
    func tabManagerDidRemoveAllTabs(_ tabManager: TabManager, toast:ButtonToast?) {

    }
    
    func tabManagerDidSwapTabs(_ tabManager: TabManager, oldTabIndex: Int, newTabIndex: Int) {
        
    }
}
