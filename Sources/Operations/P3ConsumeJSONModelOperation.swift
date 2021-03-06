//
//  P3ConsumeJSONModelOperation.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/29/17.
//  Copyright © 2017 Pacific3. All rights reserved.
//

open class P3ConsumeJSONModelOperation<T: Codable>: P3Operation {
    private let queue = P3OperationQueue()
    
    private lazy var session: URLSession = {
        return URLSession(configuration: URLSessionConfiguration.ephemeral)
    }()
    
    open var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy {
        return .base64
    }
    
    open var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        return .iso8601
    }
    
    open var endpoint: EndpointConvertible? {
        return nil
    }
    
    open var method: P3HTTPMethod {
        return .get
    }
    
    open var requestHeaders: [String:String]? {
        return nil
    }
    
    open var requestBody: [String:Any]? {
        return nil
    }
    
    open var requestBodyData: Data? {
        return nil
    }
    
    public var inflatedModel: T?
    
    public var downloadedData: Data?
    
    private var url: URL?
    
    public init(url: URL? = nil) {
        self.url = url
        super.init()
        
        name = "\(type(of: self))"
    }
    
    open override func execute() {
        let request = buildRequest()
        
        let task = session.dataTask(with: request) { [unowned self] (data, response, error) in
            self.downloadedData = data
            
            guard let data = self.downloadedData, error == nil else {
                self.finishWithError(error: error as NSError?)
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = self.dateDecodingStrategy
            decoder.dataDecodingStrategy = self.dataDecodingStrategy
            
            do {
                let inflated = try decoder.decode(T.self, from: data)
                self.inflatedModel = inflated
                self.didInflateModel(inflatedModel: inflated)
                self.finish()
            } catch {
                self.handleModelInflationError(error as NSError?)
            }
        }
        
        let taskOperation = P3URLSessionTaskOperation(task: task)
        let reachabilityCondition = P3ReachabilityCondition(host: getRequestURL())
        taskOperation.addCondition(condition: reachabilityCondition)
        
        #if os(iOS)
            taskOperation.addObserver(observer: P3NetworkActivityObserver())
        #endif
        
        queue.addOperation(taskOperation)
    }
    
    open func handleModelInflationError(_ error: NSError?) {
        self.finishWithError(error: error as NSError?)
    }
    
    open func didInflateModel(inflatedModel: T) {
        fatalError("didInflatemodel(:) needs to ve overriden")
    }
}

extension P3ConsumeJSONModelOperation {
    private func getRequestURL() -> URL {
        var _url: URL
        
        if let u = self.url {
            _url = u
        } else if let e = endpoint?.generateURL() {
            _url = e
        } else {
            fatalError("Can't launch a network request without a valir URL")
        }
        
        return _url
    }
    
    private func buildRequest() -> URLRequest {
        var request = URLRequest(url: getRequestURL())
        request.httpMethod = method.rawValue
        
        if [P3HTTPMethod.post, .put, .patch].contains(method)  {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            if let body = requestBodyData {
                request.httpBody = body
            } else if let body = requestBody {
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                } catch {
                    fatalError("Couldn't serialize request body into JSON.")
                }
            }
        }
        
        if let h = requestHeaders {
            for header in h {
                request.setValue(header.value, forHTTPHeaderField: header.key)
            }
        }
        
        return request
    }
}
