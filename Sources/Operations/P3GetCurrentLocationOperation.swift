//
//  P3GetCurrentLocationOperation.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/20/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//

import CoreLocation

public class P3GetCurrentLocationOperation: P3Operation, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    private let accuracy: CLLocationAccuracy
    private let handler: (CLLocation) -> Void
    
    public init(accuracyInMeters accuracy: CLLocationAccuracy, usage: P3LocationAvailabilityCondition.Usage = .whenInUse, locationHandler: @escaping (CLLocation) -> Void) {
        self.accuracy = accuracy
        self.handler = locationHandler
        
        super.init()
        
        addCondition(condition: P3LocationAvailabilityCondition(usage: usage))
        addCondition(condition: P3MutuallyExclusiveOperationCondition<CLLocationManager>())
    }
    
    public override func execute() {
        manager.desiredAccuracy = self.accuracy
        manager.delegate = self
        
        #if os(iOS) || os(macOS)
            manager.startUpdatingLocation()
        #else
            manager.requestLocation()
        #endif
    }
    
    public override func cancel() {
        self.stopLocationUpdates()
        super.cancel()
    }
    
    private func stopLocationUpdates() {
        manager.stopUpdatingLocation()
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy <= accuracy else {
            return
        }
        
        stopLocationUpdates()
        handler(location)
        finish()
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        stopLocationUpdates()
        finishWithError(error: error as NSError?)
    }
}
