//
//  ViewController.swift
//  WKWebWithProxy
//
//  Created by FanYu on 2022/9/6.
//

import UIKit
import WebKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = URL(string: "http://www.google.com")
        let request = URLRequest(url: url!)
        
        let config = WKWebViewConfiguration()
        config.add(ProxyConfig(host: "192.168.31.191", port: 6152))
        
        let webView = WKWebView(frame: view.frame, configuration: config)
        view.addSubview(webView)
        
        webView.load(request)
    }

}

