//
//  P3LocationAvailabilityCondition.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/20/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//

import CoreLocation

public struct P3LocationAvailabilityCondition: P3OperationCondition {
    public enum Usage {
        case whenInUse
        case always
    }
    
    static let locationServicesEnabledKey = "CLLocationServicesEnabled"
    static let authorizationStatusKey     = "CLAuthorizationStatus"
    public static var name                = "Location"
    public static var isMutuallyExclusive = false
    
    let usage: Usage
    
    public init(usage: Usage) {
        self.usage = usage
    }
    
    public func dependencyForOperation(operation: P3Operation) -> Operation? {
        return P3RequestLocationPermissionOperation(usage: usage)
    }
    
    public func evaluateForOperation(operation: Operation, completion: @escaping (P3OperationCompletionResult) -> Void) {
        let enabled = CLLocationManager.locationServicesEnabled()
        let actual = CLLocationManager.authorizationStatus()
        
        var error: NSError?
        
        switch (enabled, usage, actual) {
        case (true, _, .authorizedAlways):
            break
            
        case (true, .whenInUse, .authorizedWhenInUse):
            break
            
        default:
            error = NSError(error: P3ErrorSpecification(ec: P3OperationError.ConditionFailed), userInfo: [
                P3OperationConditionKey: type(of: self).name as AnyObject,
                type(of: self).locationServicesEnabledKey: enabled as AnyObject,
                type(of: self).authorizationStatusKey: Int(actual.rawValue) as AnyObject
                ])
        }
        
        if let error = error {
            completion(.Failed(error))
        } else {
            completion(.Satisfied)
        }
    }
}

private class P3RequestLocationPermissionOperation: P3Operation {
    let usage: P3LocationAvailabilityCondition.Usage
    var manager: CLLocationManager?
    
    init(usage: P3LocationAvailabilityCondition.Usage) {
        self.usage = usage
        
        super.init()
        
        #if os(iOS) || os(tvOS)
            addCondition(condition: AlertPresentation())
        #endif
    }
    
    fileprivate override func execute() {
        switch (CLLocationManager.authorizationStatus(), usage) {
        case (.notDetermined, _), (.authorizedWhenInUse, .always):
            p3_executeOnMainThread {
                self.requestPermission()
            }
            
        default:
            finish()
        }
        
    }
    
    private func requestPermission() {
        manager = CLLocationManager()
        manager?.delegate = self
        
        #if os(iOS) || os(tvOS)
            _requestPermissioniOS()
        #else
            _requestPermissionmacOS()
        #endif
    }
}

#if os(macOS)
    extension P3RequestLocationPermissionOperation {
        func _requestPermissionmacOS() {
            manager?.startUpdatingLocation()
        }
    }
#endif

#if os(iOS) || os(tvOS)
    extension P3RequestLocationPermissionOperation {
        func _requestPermissioniOS() {
            let key: String
            switch usage {
            case .whenInUse:
                key = "NSLocationWhenInUseUsageDescription"
                manager?.requestWhenInUseAuthorization()
                
            case .always:
                key = "NSLocationAlwaysAndWhenInUseUsageDescription"
                #if os(iOS)
                    manager?.requestAlwaysAuthorization()
                #else
                    fatalError("You can't request always on tvOS.")
                #endif
            }
            
            assert(Bundle.main.object(forInfoDictionaryKey: key) != nil, "Requesting location permission requires the \(key) in the Info.plist file!")
        }
    }
    
#endif

extension P3RequestLocationPermissionOperation: CLLocationManagerDelegate {
    fileprivate func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        #if os(iOS) || os(tvOS)
            if manager == self.manager && isExecuting && status != .notDetermined {
                finish()
            }
        #else
            if manager == self.manager && status == .notDetermined {
                // Force macOS to show the location permission dialog
                manager.startUpdatingLocation()
                manager.stopUpdatingLocation()
            }
        #endif
    }
}
