//
//  ProxyManager.swift
//  WKWebWithProxy
//
//  Created by FanYu on 2022/9/6.
//

import Foundation
import WebKit
import ObjectiveC

fileprivate let httpSchemes = ["http", "https"]

struct ProxyConfig: Equatable {
    
    let host: String
    let port: Int
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.host == rhs.host && lhs.port == rhs.port
    }
    
}

class ProxyHandler: NSObject {
    
    private let httpProxyKey = kCFNetworkProxiesHTTPEnable as String
    private let httpHostKey = kCFNetworkProxiesHTTPProxy as String
    private let httpPortKey = kCFNetworkProxiesHTTPPort as String
    private let httpsProxyKey = "HTTPSEnable"
    private let httpsHostKey = "HTTPSProxy"
    private let httpsPortKey = "HTTPSPort"
    
    private static var session: URLSession?

    private var dataTask: URLSessionDataTask?
    
    init(config: ProxyConfig) {
        super.init()
        updateSession(of: config)
    }
    
    private func updateSession(of proxyConfig: ProxyConfig) {
        if let session = Self.session, hasProxyConfig(proxyConfig, proxyDic: session.configuration.connectionProxyDictionary) {
            return
        }
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [
            httpProxyKey: true,
            httpHostKey: proxyConfig.host,
            httpPortKey: proxyConfig.port,
            httpsProxyKey: true,
            httpsHostKey: proxyConfig.host,
            httpsPortKey: proxyConfig.port
        ]
        Self.session = URLSession(configuration: config)
    }
    
    private func hasProxyConfig(_ proxyConfig: ProxyConfig, proxyDic: [AnyHashable : Any]?) -> Bool {
        guard
            let proxyDic = proxyDic,
            let host = proxyDic[httpHostKey] as? String,
            let port = proxyDic[httpPortKey] as? Int,
            proxyConfig == ProxyConfig(host: host, port: port)
        else {
            return false
        }
        return true
    }
    
}

extension ProxyHandler: WKURLSchemeHandler {
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        dataTask = Self.session?.dataTask(with: urlSchemeTask.request) { [weak urlSchemeTask] data, response, error in
            guard let urlSchemeTask = urlSchemeTask else {
                return
            }
            if let error = error, error._code != NSURLErrorCancelled {
                urlSchemeTask.didFailWithError(error)
            } else {
                if let response = response {
                    urlSchemeTask.didReceive(response)
                }
                if let data = data {
                    urlSchemeTask.didReceive(data)
                }
                urlSchemeTask.didFinish()
            }
        }
        dataTask?.resume()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        dataTask?.cancel()
    }
    
}

extension WKWebViewConfiguration {
    
    func add(_ proxyConfig: ProxyConfig) {
        let handler = ProxyHandler(config: proxyConfig)
        hookWKWebView()
        httpSchemes.forEach {
            setURLSchemeHandler(handler, forURLScheme: $0)
        }
    }
    
    private func hookWKWebView() {
        guard
            let origin = class_getClassMethod(WKWebView.self, #selector(WKWebView.handlesURLScheme(_:))),
            let hook = class_getClassMethod(WKWebView.self, #selector(WKWebView._handlesURLScheme(_:)))
        else {
            return
        }
        method_exchangeImplementations(origin, hook)
    }
    
}

fileprivate extension WKWebView {
    
    @objc static func _handlesURLScheme(_ urlScheme: String) -> Bool {
        if httpSchemes.contains(urlScheme) {
            return false
        }
        return Self.handlesURLScheme(urlScheme)
    }
    
}
