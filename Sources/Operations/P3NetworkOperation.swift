//
//  P3NetworkOperation.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/19/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//

private let urlSession = URLSession(
    configuration: URLSessionConfiguration.ephemeral
)

open class P3NetworkOperation: P3Operation {
    // MARK: - Private Support Types
    
    fileprivate enum OperationType {
        case GetData
        case Download
    }
    
    fileprivate let internalQueue = P3OperationQueue()
    
    
    // MARK: - Private Properties
    fileprivate var operationType: OperationType
    
    fileprivate var composedEndpointURL: URL? {
        if let _ = self.composedEndpoint.0 as? NullEndpoint {
            fatalError("Trying to initialize a network operation with a Null endpoint. Override the .composedEmpoint property on your subclass")
        }
        
        let (endpoint, params) = self.composedEndpoint
        return endpoint.generateURL(params: params)
    }
    
    fileprivate var simpleEndpointURL: URL? {
        if let _ = self.simpleEndpoint as? NullEndpoint {
            fatalError("Trying to initialize a network operation with a Null endpoint. Override the .simpleEndpoint property on your subclass")
        }
        
        return simpleEndpoint.generateURL()
    }
    
    
    // MARK: -  Public Support Types
    public enum DownloadConfiguration {
        case DownloadAndSaveToURL
        case DownloadAndReturnToParseManually
    }
    
    
    // MARK: - Public Properties/Overridables
    public var url: URL?
    public var networkTaskOperation: P3URLSessionTaskOperation?
    public var downloadedJSON: [String:AnyObject]?
    public let cacheFile: URL?
    
    open var downloadConfiguration: DownloadConfiguration {
        return .DownloadAndReturnToParseManually
    }
    
    open var endpointType: EndpointType {
        return .Simple
    }
    
    open var simpleEndpoint: EndpointConvertible {
        return NullEndpoint()
    }
    
    open var composedEndpoint: (EndpointConvertible, [String:String]) {
        return (NullEndpoint(), ["":""])
    }
    
    open var method: HTTPMethod {
        return .GET
    }
    
    open var headerParams: [String:String]? {
        return nil
    }
    
    open var requestBody: [String:AnyObject]? {
        return nil
    }
    
    
    // MARK: - Public Initialisers
    
    public init?(
        cacheFile: URL,
        url: URL? = nil
        ) {
        self.cacheFile       = cacheFile
        self.url             = url
        downloadedJSON       = nil
        networkTaskOperation = nil
        
        operationType = .Download
        
        super.init()
        
        if downloadConfiguration != .DownloadAndSaveToURL {
            fatalError(
                "Trying to initialize download operation" +
                    "with wrong configuration. It should be " +
                    "\(DownloadConfiguration.DownloadAndSaveToURL) but is" +
                    "\(downloadConfiguration)"
            )
            return nil
        }
        
        name = "DownloadJSONOperation<\(type(of: self))>"
    }
    
    public init?(url: URL? = nil) {
        self.url             = url
        cacheFile            = nil
        networkTaskOperation = nil
        downloadedJSON       = nil
        
        operationType = .GetData
        
        super.init()
        
        if downloadConfiguration != .DownloadAndReturnToParseManually {
            fatalError(
                "Trying to initialize download operation" +
                    "with wrong configuration. It should be " +
                    "\(DownloadConfiguration.DownloadAndReturnToParseManually)" +
                    "but is \(downloadConfiguration)"
            )
            return nil
        }
        
        name = "DownloadJSONOperation<\(type(of: self))>"
    }
    
    open override func execute() {
        guard let request = buildRequest() else {
            return
        }
        
        switch operationType {
        case .Download:
            networkTaskOperation = getDownloadTaskOperationWithRequest(request: (request as NSURLRequest) as URLRequest)
            
        case .GetData:
            networkTaskOperation = getDataTaskOperationWithRequest(request: request)
        }
        
        if let op = networkTaskOperation {
            internalQueue.addOperation(op)
        }
    }
    
    public func jsonDownloadComplete() {
        
    }
    
    public func downloadToURLComplete() {
        
    }
}


// MARK: - Private Methods
extension P3NetworkOperation {
    fileprivate func buildRequest() -> URLRequest? {
        guard let url = getURL() else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = getRequestBodyData()
        
        if let headerParams = headerParams {
            for param in headerParams {
                request.setValue(param.1, forHTTPHeaderField: param.0)
            }
        }
        
        return request
    }
    
    fileprivate func getDataTaskOperationWithRequest(
        request: URLRequest
        ) -> P3URLSessionTaskOperation {
        let task = urlSession.dataTask(with: request, completionHandler: { (data, response, error) in
            self.dataRequestFinishedWithData(
                data: data,
                response: response,
                error: error
            )
        })
        
        
        let networkTaskOperation = P3URLSessionTaskOperation(task: task)
        
        return prepareNetworkTaskOperation(networkTaskOperation: networkTaskOperation)
    }
    
    fileprivate func getDownloadTaskOperationWithRequest(
        request: URLRequest
        ) -> P3URLSessionTaskOperation {
        let task = urlSession.downloadTask(with: request) {
            url, response, error in
            self.downloadRequestFinishedWithUrl(
                url: url,
                response: response,
                error: error
            )
        }
        
        let networkTaskOperation = P3URLSessionTaskOperation(task: task)
        
        return prepareNetworkTaskOperation(networkTaskOperation: networkTaskOperation)
    }
    
    fileprivate func dataRequestFinishedWithData(
        data: Data?,
        response: URLResponse?,
        error: Error?
        ) {
        if let error = error {
            finishWithError(error: error as NSError)
            
            return
        }
        
        guard let data = data else {
            return
        }
        
        guard let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else {
            finish()
            return
        }
        
        let s = "{\"result\":\(jsonString)}"
        
        let newJsonData = (s as NSString).data(using: String.Encoding.utf8.rawValue)!
        
        do {
            let json = try JSONSerialization.jsonObject(with: newJsonData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String:AnyObject]
            self.downloadedJSON = json
            jsonDownloadComplete()
            finish()
        } catch let error as NSError {
            finishWithError(error: error)
            
            return
        }
    }
    
    fileprivate func downloadRequestFinishedWithUrl(
        url: URL?,
        response: URLResponse?,
        error: Error?
        ) {
        guard let cacheFile = cacheFile else {
            return
        }
        
        if let localUrl = url {
            do {
                try FileManager.default.removeItem(at: cacheFile)
            } catch { }
            
            do {
                try FileManager.default.moveItem(
                    at: localUrl,
                    to: cacheFile
                )
            } catch let error as NSError {
                print("error moving file!: \(error)")
                finishWithError(error: error)
            }
        } else if let error = error {
            print("error downloading data!: \(error)")
            finishWithError(error: error as NSError)
        } else {}
    }
    
    fileprivate func getURL() -> URL? {
        var _url: URL?
        
        if let defaultURL = url {
            _url = defaultURL
        } else {
            switch endpointType {
            case .Simple:
                _url = simpleEndpointURL
                
            case .Composed:
                _url = composedEndpointURL
            }
        }
        
        return _url
    }
    
    fileprivate func getRequestBodyData() -> Data? {
        if let requestBody = requestBody {
            do {
                let requestData = try JSONSerialization.data(
                    withJSONObject: requestBody,
                    options: .prettyPrinted
                )
                return requestData
            } catch {
                debugPrint("Data \(requestBody) could not be serialized.")
            }
        }
        
        return nil
    }
    
    private func prepareNetworkTaskOperation(networkTaskOperation: P3URLSessionTaskOperation) -> P3URLSessionTaskOperation {
        if let url = networkTaskOperation.task.originalRequest?.url {
            let reachabilityCondition = P3ReachabilityCondition(host: url)
            networkTaskOperation.addCondition(condition: reachabilityCondition)
        }
        
        #if os(iOS)
        let networkObserver = P3NetworkActivityObserver()
        networkTaskOperation.addObserver(observer: networkObserver)
        #endif
        
        return networkTaskOperation
    }
}

extension P3NetworkOperation.DownloadConfiguration: CustomStringConvertible {
    public var description: String {
        switch self {
        case .DownloadAndReturnToParseManually:
            return ".DownloadAndReturnToParseManually"
            
        case .DownloadAndSaveToURL:
            return ".DownloadAndSaveToURL"
        }
    }
}

