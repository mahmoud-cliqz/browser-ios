//
//  InterceptorURLProtocol.swift
//  Client
//
//  Created by Mahmoud Adam on 6/22/16.
//  Copyright © 2016 CLIQZ. All rights reserved.
//

import UIKit


class InterceptorURLProtocol: NSURLProtocol {
    var connection: NSURLConnection?
    
    static let customURLProtocolHandledKey = "customURLProtocolHandledKey"
    static let excludeUrlPrefixes = ["https://lookback.io/api", "http://localhost"]
    
    //MARK: - NSURLProtocol handling
    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        if NSURLProtocol.propertyForKey(customURLProtocolHandledKey, inRequest: request) != nil{
            return false
        }
        
        if let url = request.URL?.absoluteString where isExcludedUrl(url) == false {
            return true
        }
        return false
        
    }
    
    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }
    
    override class func requestIsCacheEquivalent(a: NSURLRequest, toRequest b: NSURLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, toRequest: b)
    }

    override func startLoading() {
        let newRequest = self.request.mutableCopy() as! NSMutableURLRequest
        NSURLProtocol.setProperty(true, forKey: InterceptorURLProtocol.customURLProtocolHandledKey, inRequest: newRequest)
        
        let requestInfo = getRequestInfo(request)
        if let blockResponse = AntiTrackingModule.sharedInstance.getBlockResponseForRequest(requestInfo) where blockResponse.count > 0 {
            
            if let block = blockResponse["block"] as? Bool where block == true {
                print("\n\n[Anti-Tracking] request blocked, URL: \(request.URL)\n\n")
                return
            }
            
            if let redirectUrl = blockResponse["redirectUrl"] as? String {
                newRequest.URL = NSURL(string: redirectUrl)!
                print("\n\n[Anti-Tracking] request redirected, \noriginal URL:\n\(request.URL?.absoluteString) \n\nredirect URL:\n\(redirectUrl)\n\n")
            }
            if let requestHeaders = blockResponse["requestHeaders"] as? [[String: String]] {
                
                for requestHeader in requestHeaders {
                    newRequest.setValue(requestHeader["value"], forHTTPHeaderField: requestHeader["name"]!)
                }
                
                print("\n\n[Anti-Tracking] request headers modified, URL: \(requestHeaders)\n\n")
            }
        }
        
        self.connection = NSURLConnection(request: newRequest, delegate: self)
    }
    
    override func stopLoading() {
        self.connection?.cancel()
        self.connection = nil
    }

    
    //MARK: - NSURLConnectionDataDelegate
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        self.client?.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.client?.URLProtocol(self, didLoadData: data)
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        self.client?.URLProtocolDidFinishLoading(self)

    }
    
    func didFailWithError(error: NSError) {
        self.client?.URLProtocol(self, didFailWithError: error)
    }
    
    //MARK: - private helper methods
    class func isExcludedUrl(url: String) -> Bool {
        if url.startsWith("http") == false {
            return true
        }
        for prefix in excludeUrlPrefixes {
            if url.startsWith(prefix) {
                return true
            }
        }
        return false
    }
    
    func getRequestInfo(request: NSURLRequest) -> [String: AnyObject] {
        let url = request.URL?.absoluteString
        
        let isMainDocument = request.URL == request.mainDocumentURL
        let tabId = getTabId(request.mainDocumentURL)
        let isPrivate = false
        let originUrl = request.mainDocumentURL?.absoluteString
        
        
        var requestInfo = [String: AnyObject]()
        requestInfo["url"] = url
        requestInfo["method"] = request.HTTPMethod
        requestInfo["tabId"] = tabId ?? 0
        requestInfo["parentFrameId"] = -1
        requestInfo["frameId"] = -1
        requestInfo["type"] = isMainDocument ? 6 : 11
        requestInfo["isPrivate"] = isPrivate
        requestInfo["originUrl"] = originUrl
        
        requestInfo["requestHeaders"] = request.allHTTPHeaderFields
        return requestInfo
    }
    private func getTabId(mainDocumentURL: NSURL?) -> Int? {
        if let url = mainDocumentURL?.absoluteString {
            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            return appDelegate.tabManager.getTabId(url)
        }
        
        return nil
    }
}
