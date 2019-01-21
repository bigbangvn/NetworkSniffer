//
//  NetworkSniffer.swift
//  NetworkSniffer
//
//  Created by Bang Nguyen on 21/1/19.
//  Copyright © 2019 Bang Nguyen. All rights reserved.
//

import UIKit

final class NetworkSniffer {

  public static func startRecording() {
    //URLProtocol.registerClass(NetworkRedirectUrlProtocol.self)
    URLProtocol.registerClass(SnifferProtocol.self)
    swizzleProtocolClasses()
  }

  public static func stopRecording() {
    //URLProtocol.unregisterClass(NetworkRedirectUrlProtocol.self)
    URLProtocol.unregisterClass(SnifferProtocol.self)
    swizzleProtocolClasses()
  }

  static func swizzleProtocolClasses(){
    let instance = URLSessionConfiguration.default
    let uRLSessionConfigurationClass: AnyClass = object_getClass(instance)!

    let method1: Method = class_getInstanceMethod(uRLSessionConfigurationClass, #selector(getter: uRLSessionConfigurationClass.protocolClasses))!
    let method2: Method = class_getInstanceMethod(URLSessionConfiguration.self, #selector(URLSessionConfiguration.fakeProcotolClasses))!

    method_exchangeImplementations(method1, method2)
  }

  static func swizzleSession() {
    //Only work on iOS < 9, new iOS need to use private class :(
    let cls = URLSessionTask.self
    let sel = #selector(URLSessionTask.resume)
    guard let method1 = class_getInstanceMethod(cls, sel),
      let method2 = class_getInstanceMethod(cls, #selector(URLSessionTask.swizzle_resume)) else {
        assertionFailure()
        return
    }
    method_exchangeImplementations(method1, method2)
  }

  static func listenSessionDownloadTaskFinish() {
    
  }

}
extension URLSession {
}

extension URLSessionTask {
  @objc func swizzle_resume() {
    print("resume task: \(self)")
    swizzle_resume()
  }
}

extension URLSessionConfiguration {

  @objc func fakeProcotolClasses() -> [AnyClass]? {
    //        return [NetworkRedirectUrlProtocol.self]
    guard let fakeProcotolClasses = self.fakeProcotolClasses() else {
      return []
    }
    var originalProtocolClasses = fakeProcotolClasses.filter {
      return $0 != SnifferProtocol.self
    }
    originalProtocolClasses.insert(SnifferProtocol.self, at: 0)
    return originalProtocolClasses
  }

}
