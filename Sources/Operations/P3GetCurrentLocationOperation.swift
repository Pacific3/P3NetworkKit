//
//  P3GetCurrentLocationOperation.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/20/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//


import CoreLocation

public class P3GetCurrentLocationOperation: P3Operation, CLLocationManagerDelegate {
    
    private let accuracy: CLLocationAccuracy
    private var manager: CLLocationManager?
    private let handler: (CLLocation) -> Void
    
    public init(accuracy: CLLocationAccuracy, locationHandler: (CLLocation) -> Void) {
        self.accuracy = accuracy
        self.handler = locationHandler
        
        super.init()
        
        addCondition(condition: P3LocationAvailabilityCondition(usage: .WhenInUse))
        addCondition(condition: P3MutuallyExclusiveOperationCondition<CLLocationManager>())
    }
    
    public override func execute() {
        p3_executeOnMainThread {
            let manager = CLLocationManager()
            manager.desiredAccuracy = self.accuracy
            manager.delegate = self
            manager.startUpdatingLocation()
            
            self.manager = manager
        }
    }
    
    public override func cancel() {
        p3_executeOnMainThread {
            self.stopLocationUpdates()
            super.cancel()
        }
    }
    
    private func stopLocationUpdates() {
        manager?.stopUpdatingLocation()
        manager = nil
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last where location.horizontalAccuracy <= accuracy else {
            return
        }
        
        stopLocationUpdates()
        handler(location)
        finish()
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: NSError) {
        stopLocationUpdates()
        finishWithError(error: error)
    }
}
