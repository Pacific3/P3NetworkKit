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
    
    public func dependencyForOperation(operation: Operation) -> Operation? {
        return nil
    }

    public func evaluateForOperation(operation: Operation, completion: (P3OperationCompletionResult) -> Void) {
        ReachabilityController.requestReachability(url: host) { reachable in
            if reachable {
                completion(.Satisfied)
            } else {
                let error = NSError(error: P3ErrorSpecification(
                    ec: P3OperationError.ConditionFailed),
                                    userInfo: [
                                        P3OperationConditionKey: self.dynamicType.name,
                                        self.dynamicType.hostKey: self.host
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
        label: "P3NetworkKit.Reachabilty",
        attributes: DispatchQueueAttributes.serial,
        target: nil
    )
    
    static func requestReachability(url: NSURL, completionHandler: (Bool) -> Void) {
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
