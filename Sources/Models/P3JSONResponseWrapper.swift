//
//  P3JSONResponseWrapper.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/29/17.
//  Copyright © 2017 Pacific3. All rights reserved.
//

open class P3JSONResponseWrapper<T: Codable>: Codable {
    public enum Status: String, Codable {
        case success = "success"
        case error = "error"
    }
    
    public enum CodingKeys: String, CodingKey {
        case status
        case data
        
        case errorMessage = "error_message"
    }
    
    public var status: Status
    public var errorMessage: String?
    public var data: T?
    
    public init(status: Status, data: T? = nil, errorMessage: String? = nil) {
        self.status = status
        self.data = data
        self.errorMessage = errorMessage
    }
}
