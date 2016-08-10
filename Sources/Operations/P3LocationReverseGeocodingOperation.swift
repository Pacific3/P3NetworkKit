//
//  P3LocationReverseGeocodingOperation.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/20/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//

import CoreLocation

public typealias P3ReverseGeocodingCompletion = (CLPlacemark) -> Void

private class _ReverseGeocodeOperation: P3Operation {
    private let geoCoder = CLGeocoder()
    private var completion: P3ReverseGeocodingCompletion
    private var locationToGeocode: CLLocation
    
    init(location: CLLocation, completion: P3ReverseGeocodingCompletion) {
        locationToGeocode = location
        self.completion = completion
    }
    
    override func execute() {
        geoCoder.reverseGeocodeLocation(locationToGeocode) { placemarks, error in
            guard let placemark = placemarks?.first else {
                self.finishWithError(error: NSError(error: P3ErrorSpecification(ec: P3OperationError.ExecutionFailed)))
                return
            }
            
            self.completion(placemark)
            self.finish()
        }
    }
}

public class ReverseGeocodeOperation: P3GroupOperation {
    private let geocodeOperation: _ReverseGeocodeOperation
    
    public init(location: CLLocation, completion: P3ReverseGeocodingCompletion) {
        geocodeOperation = _ReverseGeocodeOperation(location: location, completion: completion)
        #if os(iOS)
            geocodeOperation.addObserver(observer: P3NetworkActivityObserver())
        #endif
        
        super.init(operations: [geocodeOperation])
        name = "Reverse Geocode Operation"
    }
}
