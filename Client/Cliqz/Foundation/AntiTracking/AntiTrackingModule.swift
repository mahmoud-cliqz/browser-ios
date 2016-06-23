//
//  AntiTrackingModule.swift
//  Client
//
//  Created by Mahmoud Adam on 6/21/16.
//  Copyright © 2016 CLIQZ. All rights reserved.
//

import UIKit
import JavaScriptCore
import Crashlytics


class AntiTrackingModule: NSObject {
    
    //MARK: Constants
    private let context = JSContext()
    private let antiTrackingDirectory = "Extension/build/mobile/search/v8"
    private let documentDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
    
    // MARK: - Local variables
    var privateMode = false
    var timerCounter = 0
    var timers = [Int: NSTimer]()
    
    //MARK: - Singltone
    static let sharedInstance = AntiTrackingModule()
    
    override init() {
        super.init()
        configureExceptionHandler()
        loadModule()
        
        // Register interceptor url protocol
        NSURLProtocol.registerClass(InterceptorURLProtocol)
    }
    
    //MARK: - Public APIs
    func getBlockResponseForRequest(requestInfo: [String: AnyObject]) -> [NSObject : AnyObject]? {
        
        if let requestInfoJsonString = toJSONString(requestInfo) {
            
            let onBeforeRequestCall = "System.get('platform/webrequest').default.onBeforeRequest._trigger(\(requestInfoJsonString));"
            
            let blockResponse = context.evaluateScript(onBeforeRequestCall)
            return blockResponse.toDictionary()
        }
        
        return nil
    }
    //MARK: - Private Helpers
    private func toJSONString(anyObject: AnyObject) -> String? {
        do {
            
            if NSJSONSerialization.isValidJSONObject(anyObject) {
                let jsonData = try NSJSONSerialization.dataWithJSONObject(anyObject, options: NSJSONWritingOptions(rawValue: 0))
                let jsonString = String(data:jsonData, encoding: NSUTF8StringEncoding)!
                return jsonString
            } else {
                print("[toJSONString] the following object is not valid JSON: \(anyObject)")
            }
        } catch let error as NSError {
            print("[toJSONString] JSON conversion of: \(anyObject) \n failed with error: \(error)")
        }
        return nil
    }
    
    private func loadModule() {
        
        // set up System global for module import
        context.evaluateScript("var exports = {}")
        loadJavascriptSource("system-polyfill")
        context.evaluateScript("var System = exports.System;")
        loadJavascriptSource("fs-polyfill")
        
        // load config file
        loadConfigFile()
        
        // register methods
        registerNativeMethods()
        
        // import base libs
        loadJavascriptSource("CliqzUtils")
        loadJavascriptSource("CliqzEvents")
        context.evaluateScript("var CLIQZEnvironment = {};")
        context.evaluateScript("var CliqzLanguage = {};")
        context.evaluateScript("var Components = {};")
        
        // pref config
        context.evaluateScript("CliqzUtils.setPref(\"antiTrackTest\", true);")
        context.evaluateScript("CliqzUtils.setPref(\"attrackForceBlock\", false);")
        context.evaluateScript("CliqzUtils.setPref(\"attrackBloomFilter\", true);")
        context.evaluateScript("CliqzUtils.setPref(\"attrackDefaultAction\", \"placeholder\");")
        
        // load promise
        loadJavascriptSource("es6-promise")
        
        // startup
        context.evaluateScript("System.import(\"platform/startup\").then(function(startup) { startup.default() }).catch(function(e) { logDebug(e, \"xxx\"); });")
        
    }
    
    private func loadJavascriptSource(sourcePath: String) {
        let (sourceName, directory) = getSourceMetaData(sourcePath)
        if let path = NSBundle.mainBundle().pathForResource(sourceName, ofType: "js", inDirectory: directory), script = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding) as String {
            context.evaluateScript(script);
        }
    }
    
    private func getSourceMetaData(sourcePath: String) -> (String, String) {
        var sourceName: String
        var directory: String
        if sourcePath.contains("/") {
            var pathComponents = sourcePath.componentsSeparatedByString("/")
            sourceName = pathComponents.last!
            pathComponents.removeLast()
            directory = antiTrackingDirectory + pathComponents.joinWithSeparator("/")
        } else {
            sourceName = sourcePath
            directory = antiTrackingDirectory
        }
        
        if sourceName.endsWith(".js") {
            sourceName = sourceName.replace(".js", replacement: "")
        }
        return (sourceName, directory)
    }
    
    private func loadConfigFile() {
        if let path = NSBundle.mainBundle().pathForResource("cliqz", ofType: "json", inDirectory: "\(antiTrackingDirectory)/config"), script = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding) as String {
            let formatedScript = script.replace("\"", replacement: "\\\"").replace("\n", replacement: "")
            let configScript = "var __CONFIG__ = JSON.parse(\"\(formatedScript)\");"
            context.evaluateScript(configScript)
        }
    }
    private func configureExceptionHandler() {
        context.exceptionHandler = { context, exception in
            print("JS Error: \(exception)")
        }
    }
    
    private func registerNativeMethods() {
        registerMd5NativeMethod()
        registerLogDebugMethod()
        registerLoadSubscriptMethod()
        registerSetTimeoutMethod()
        registerSetIntervalMethod()
        registerClearIntervalMethod()
        registerReadFileMethod()
        registerWriteFileMethod()
        registerHttpHandlerMethod()
    }
    private func registerMd5NativeMethod() {
        let md5Native: @convention(block) (String) -> String = { data in
            return self.md5(string: data)
        }
        context.setObject(unsafeBitCast(md5Native, AnyObject.self), forKeyedSubscript: "_md5Native")
    }
    
    private func md5(string string: String) -> String {
        var digest = [UInt8](count: Int(CC_MD5_DIGEST_LENGTH), repeatedValue: 0)
        if let data = string.dataUsingEncoding(NSUTF8StringEncoding) {
            CC_MD5(data.bytes, CC_LONG(data.length), &digest)
        }
        
        var digestHex = ""
        for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
            digestHex += String(format: "%02x", digest[index])
        }
        
        return digestHex
    }
    
    private func registerLogDebugMethod() {
        let logDebug: @convention(block) (String, String) -> () = { message, key in
            NSLog("\n\n>>>>>>>> \(key): \(message)\n\n")
        }
        context.setObject(unsafeBitCast(logDebug, AnyObject.self), forKeyedSubscript: "logDebug")
    }
    private func registerLoadSubscriptMethod() {
        let loadSubscript: @convention(block) String -> () = { subscriptName in
            self.loadJavascriptSource("/modules\(subscriptName)")
        }
        context.setObject(unsafeBitCast(loadSubscript, AnyObject.self), forKeyedSubscript: "loadSubScript")

    }
    private func registerSetTimeoutMethod() {
        let setTimeout: @convention(block) (JSValue, Int) -> () = { function, timeoutMsec in
            let delay = Double(timeoutMsec) * Double(NSEC_PER_MSEC)
            let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
            dispatch_after(time, dispatch_get_main_queue(), {
                function.callWithArguments(nil)
            })
        }
        context.setObject(unsafeBitCast(setTimeout, AnyObject.self), forKeyedSubscript: "setTimeout")
    }
    
    private func registerSetIntervalMethod() {
        let setInterval: @convention(block) (JSValue, Int) -> Int = { function, interval in
            let timerId = self.timerCounter
            self.timerCounter += 1
            let timeInterval = NSTimeInterval(interval)
            let timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval,
                                                               target: self,
                                                               selector: #selector(AntiTrackingModule.excuteJavaScriptFunction(_:)),
                                                               userInfo: function,
                                                               repeats: true)
            
            self.timers[timerId] = timer
            return timerId
        }
        context.setObject(unsafeBitCast(setInterval, AnyObject.self), forKeyedSubscript: "setInterval")
    }
    @objc private func excuteJavaScriptFunction(timer: NSTimer) -> () {
        if let function = timer.userInfo as? JSValue {
            function.callWithArguments(nil)
        }
    }
    
    private func registerClearIntervalMethod() {
        let clearInterval: @convention(block) Int -> () = { timerId in
            if let timer = self.timers[timerId] {
                timer.invalidate()
            }
        }
        context.setObject(unsafeBitCast(clearInterval, AnyObject.self), forKeyedSubscript: "clearInterval")
    }
    
    
    private func registerReadFileMethod() {
        let readFile: @convention(block) (String, JSValue) -> () = { path, callback in
            let filePathURL = NSURL(fileURLWithPath: self.documentDirectory).URLByAppendingPathComponent(path)
            do {
                let content = try String(contentsOfURL: filePathURL)
                callback.callWithArguments([content])
            } catch {
                // files does not exist, do no thing
            }
        }
        context.setObject(unsafeBitCast(readFile, AnyObject.self), forKeyedSubscript: "readFile")
    }
    
    
    private func registerWriteFileMethod() {
        let writeFile: @convention(block) (String, String) -> () = { path, data in
            let filePathURL = NSURL(fileURLWithPath: self.documentDirectory).URLByAppendingPathComponent(path)
            do {
                try data.writeToURL(filePathURL, atomically: true, encoding: NSUTF8StringEncoding)

            } catch let error as NSError {
                Answers.logCustomEventWithName("AntiTrackingWriteFileError", customAttributes: ["path": path, "error": error.localizedDescription])
            }

        }
        context.setObject(unsafeBitCast(writeFile, AnyObject.self), forKeyedSubscript: "writeFile")
    }
    
    private func registerHttpHandlerMethod() {
        let httpHandler: @convention(block) (String, String, JSValue, JSValue, Int, String) -> () = { method, requestedUrl, callback, onerror, timeout, data in
            if requestedUrl.startsWith("file://") {
                let (fileName, fileExtension, directory) = self.getFileMetaData(requestedUrl)
                if let path = NSBundle.mainBundle().pathForResource(fileName, ofType: fileExtension, inDirectory: directory), content = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding) as String {
                    callback.callWithArguments([content])
                }
            } else {
                var hasError = false
                
                if NetworkReachability.sharedInstance.networkReachabilityStatus != .ReachableViaWiFi {
                    hasError = true
                } else {
                    if method == "GET" {
                        ConnectionManager.sharedInstance
                            .sendGetRequest(requestedUrl,
                                            parameters: nil,
                                            onSuccess: { responseData in
                                                self.httpHandlerReply(responseData, callback: callback, onerror: onerror)
                                            },
                                            onFailure: { (data, error) in
                                                onerror.callWithArguments([])
                                            })
                        
                    } else if method == "POST" {
                        
                        ConnectionManager.sharedInstance
                            .sendPostRequest(requestedUrl,
                                            body: data,
                                            enableCompression: false,
                                            onSuccess: { responseData in
                                                self.httpHandlerReply(responseData, callback: callback, onerror: onerror)
                                            },
                                            onFailure: { (data, error) in
                                                onerror.callWithArguments([])
                            })
                        
                    } else {
                        hasError = true
                    }
                }
                
                if hasError {
                    onerror.callWithArguments([])
                }
            }
            
        }
        context.setObject(unsafeBitCast(httpHandler, AnyObject.self), forKeyedSubscript: "httpHandler")
    }
    private func httpHandlerReply(responseData: AnyObject, callback: JSValue, onerror: JSValue) {
        if let responseString = self.toJSONString(responseData) {
            let response = ["status": 200, "responseText": responseString, "response": responseString]
            callback.callWithArguments([response])
        } else {
            onerror.callWithArguments([])
        }
        
    }
    private func getFileMetaData(requestedUrl: String) -> (String, String, String) {
        var fileName: String
        var fileExtension: String = "js" // default is js
        var directory: String
        
        var sourcePath = requestedUrl.replace("file://", replacement: "")
        sourcePath = sourcePath.replace("/v8", replacement: "")
        
        if sourcePath.contains("/") {
            var pathComponents = sourcePath.componentsSeparatedByString("/")
            fileName = pathComponents.last!
            pathComponents.removeLast()
            directory = antiTrackingDirectory + pathComponents.joinWithSeparator("/")
        } else {
            fileName = sourcePath
            directory = antiTrackingDirectory
        }
        
        if fileName.contains(".") {
            let nameComponents = fileName.componentsSeparatedByString(".")
            fileName = nameComponents[0]
            fileExtension = nameComponents[1]
        }
        return (fileName, fileExtension, directory)
    }
}
