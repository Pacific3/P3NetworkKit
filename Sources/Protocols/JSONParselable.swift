//
//  JSONParselable.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/19/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//

public protocol JSONParselable {
    static func with(json: [String:Any]) -> Self?
}

public struct NullParselable: JSONParselable {
    public static func with(json: [String : Any]) -> NullParselable? {
        return nil
    }
}

