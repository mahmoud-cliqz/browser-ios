//
//  TabView.swift
//  Client
//
//  Created by Mahmoud Adam on 8/22/17.
//  Created based on https://github.com/graetzer/SGTabs for Objective C
//

import UIKit

class TabView: UIView {
    // MARK: - Constants`
    static let urlKeyPath = "url"
    private let tabColor = TabsToolbarUX.kTabColor
    private let tabDarkerColor = TabsToolbarUX.kTabDarkerColor
    
    // MARK: - Instance varialbes
    var selected = false
    private var tabSize: CGSize?
    
    lazy var closeButton: UIButton = {
        let button = UIButton.init(type: .custom)
        button.autoresizingMask = .flexibleRightMargin
        button.contentVerticalAlignment = .center
        button.setTitle("x", for: .normal)
        button.setTitleColor(UIColor.gray, for: .normal)
        button.showsTouchWhenHighlighted = true
        button.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 17.0)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel.init(frame: CGRect.zero)
        label.textAlignment = .center;
        label.lineBreakMode = .byTruncatingTail;
        label.autoresizingMask = .flexibleWidth;
        label.backgroundColor = UIColor.clear
        label.font = UIFont.init(name: "HelveticaNeue-Bold", size: 14.0)
        label.textColor = UIColor.darkGray
        return label
    } ()
    
    var tab: Tab
    
    // MARK: - initialization
    init(frame: CGRect, tab: Tab) {
        
        self.tab = tab
        super.init(frame: frame)
        
        tab.addObserver(self, forKeyPath: TabView.urlKeyPath, options: .new, context: nil)
        
        self.isExclusiveTouch = true
        self.backgroundColor = UIColor.clear
        self.contentMode = .redraw;
        self.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin, .flexibleRightMargin]
        self.addSubview(self.closeButton)
        self.addSubview(self.titleLabel)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        tab.removeObserver(self, forKeyPath: TabView.urlKeyPath)
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let _ = object as? Tab else { return }

        if keyPath == TabView.urlKeyPath {
            updateTabTitle()
        }
    }
    
    func updateTabTitle() {
        var title  = tab.displayTitle
        let freshtab = tab.displayURL?.absoluteString.contains("cliqz/goto.html") ?? false
        if tab.displayURL == nil || freshtab {
            title = NSLocalizedString("Cliqz Tab" , tableName: "Cliqz", comment: "New tab title")
        }
        
        self.updateView(withTitle: title, font: self.titleLabel.font)
    }
    
    // MARK: - Drawing
    
    override func layoutSubviews() {
        let b = self.bounds
        let margin = TabsToolbarUX.kCornerRadius
        
        if var t = tabSize {
            if t.width > b.size.width*0.75 {
                t.width = b.size.width*0.75 - 2*margin
            }
            
            if self.closeButton.isHidden {
                self.titleLabel.frame = CGRect(x: (b.size.width - t.width)/2,
                                               y: (b.size.height - t.height)/2,
                                               width: t.width,
                                               height: t.height)
            } else {
                
                self.titleLabel.frame = CGRect(x: (b.size.width - t.width)/2 + margin,
                                               y: (b.size.height - t.height)/2,
                                               width: t.width,
                                               height: t.height)
            }
        }
        
        
        self.closeButton.frame = CGRect(x: margin, y: 0, width: 25, height: b.size.height)
    }
    
    override func draw(_ rect: CGRect) {
        let tabRect   = self.bounds;
        let tabLeft   = tabRect.origin.x;
        let tabRight  = tabRect.origin.x + tabRect.size.width;
        let tabTop    = tabRect.origin.y;
        let tabBottom = tabRect.origin.y + tabRect.size.height;
        let cornerRadius = TabsToolbarUX.kCornerRadius
        let shadowRadius = TabsToolbarUX.kShadowRadius
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: tabLeft, y: tabTop))
        
        // Top left
        path.addArc(center: CGPoint(x: tabLeft, y: tabTop + cornerRadius),
                    radius: cornerRadius,
                    startAngle: -CGFloat(Double.pi/2),
                    endAngle: 0,
                    clockwise: false)
        path.addLine(to: CGPoint(x: tabLeft + cornerRadius, y: tabBottom - cornerRadius))
        

        // Bottom left
        path.addArc(center: CGPoint(x: tabLeft + 2*cornerRadius, y: tabBottom - cornerRadius),
                    radius: cornerRadius,
                    startAngle: CGFloat(Double.pi),
                    endAngle: CGFloat(Double.pi/2),
                    clockwise: true)
        path.addLine(to: CGPoint(x: tabRight - 2*cornerRadius, y: tabBottom))
        
        // Bottom rigth
        path.addArc(center: CGPoint(x: tabRight - 2*cornerRadius, y: tabBottom),
                    radius: cornerRadius,
                    startAngle: CGFloat(Double.pi/2),
                    endAngle: 0,
                    clockwise: true)
        path.addLine(to: CGPoint(x: tabRight - cornerRadius, y: tabTop + cornerRadius))

        // Top rigth
        path.addArc(center: CGPoint(x: tabRight, y: tabTop + cornerRadius),
                    radius: cornerRadius,
                    startAngle: CGFloat(Double.pi),
                    endAngle: -CGFloat(Double.pi/2),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: tabRight, y: tabTop))
        path.addLine(to: CGPoint(x: tabLeft, y: tabTop))
        path.closeSubpath()


        // Fill with current tab color
        if let ctx = UIGraphicsGetCurrentContext() {
            let startColor = self.selected ? self.tabColor.cgColor : self.tabDarkerColor.cgColor;
            ctx.setFillColor(startColor)
            ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: shadowRadius)
            ctx.addPath(path)
            ctx.fillPath()
        }

    }
    
    // MARK: - Private helper methods
    
    private func updateView(withTitle title: String?, font: UIFont?) {
        guard let title = title, let font = font else { return }
        
        self.titleLabel.text = title
        self.tabSize = title.size(attributes: [NSFontAttributeName: font])
        self.setNeedsLayout()
    }
}
