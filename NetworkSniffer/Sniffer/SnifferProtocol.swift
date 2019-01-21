//
//  SnifferProtocol.swift
//  NetworkSniffer
//
//  Created by Bang Nguyen on 21/1/19.
//  Copyright © 2019 Bang Nguyen. All rights reserved.
//

import Foundation

class SnifferProtocol: URLProtocol {
  open override class func canInit(with request: URLRequest) -> Bool {
    print("\(self) \(#function) Method: \(request.httpMethod) \n url: \(request.url) \n bodySize: \(request.httpBody?.count)")
    return false
  }

//  open override class func canonicalRequest(for request: URLRequest) -> URLRequest {
//    let mutableRequest: NSMutableURLRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
//    URLProtocol.setProperty("YES", forKey: "NetworkRequestSniffableUrlProtocol", in: mutableRequest)
//    return mutableRequest.copy() as! URLRequest
//  }

}
