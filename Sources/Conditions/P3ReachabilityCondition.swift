//
//  P3ReachabilityCondition.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/19/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//

import SystemConfiguration

public struct P3ReachabilityCondition: P3OperationCondition {
    static let hostKey = "Host"
    public static let name = "Reachability"
    public static let isMutuallyExclusive = false
    
    let host: URL
    
    init(host: URL) {
        self.host = host
    }
    
    public func dependencyForOperation(operation: P3Operation) -> Operation? {
        return nil
    }

    public func evaluateForOperation(operation: Operation, completion: @escaping (P3OperationCompletionResult) -> Void) {
        ReachabilityController.requestReachability(url: host as NSURL) { reachable in
            if reachable {
                completion(.Satisfied)
            } else {
                let error = NSError(error: P3ErrorSpecification(
                    ec: P3OperationError.ConditionFailed),
                                    userInfo: [
                                        P3OperationConditionKey as NSString: type(of: self).name as AnyObject,
                                        type(of: self).hostKey as NSString: self.host as AnyObject
                    ]
                )
                
                completion(.Failed(error))
            }
        }
    }
}

private class ReachabilityController {
    static var reachabilityRefs = [String: SCNetworkReachability]()
    
    static let reachabilityQueue = DispatchQueue(
        label: "P3NetworkKit.Reachability"
    )
    
    static func requestReachability(url: NSURL, completionHandler: @escaping (Bool) -> Void) {
        if let host = url.host {
            reachabilityQueue.async {
                var ref = self.reachabilityRefs[host]
                
                if ref == nil {
                    let hostString = host as NSString
                    ref = SCNetworkReachabilityCreateWithName(nil, hostString.utf8String!)
                }
                
                if let ref = ref {
                    self.reachabilityRefs[host] = ref
                    
                    var reachable = false
                    var flags: SCNetworkReachabilityFlags = []
                    if SCNetworkReachabilityGetFlags(ref, &flags) != Bool(0) {
                        /*
                         Note that this is a very basic "is reachable" check.
                         Your app may choose to allow for other considerations,
                         such as whether or not the connection would require
                         VPN, a cellular connection, etc.
                         */
                        reachable = flags.contains(.reachable)
                    }
                    completionHandler(reachable)
                }
                else {
                    completionHandler(false)
                }
            }
        }
        else {
            completionHandler(false)
        }
    }
}
