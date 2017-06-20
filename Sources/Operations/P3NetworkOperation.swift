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
        case getData
        case download
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
        case downloadAndSaveToURL
        case downloadAndReturnToParseManually
    }
    
    
    // MARK: - Public Properties/Overridables
    public var url: URL?
    public var networkTaskOperation: P3URLSessionTaskOperation?
    public var downloadedJSON: [String:Any]?
    public var downloadedData: Data?
    public let cacheFile: URL?
    
    open var downloadConfiguration: DownloadConfiguration {
        return .downloadAndReturnToParseManually
    }
    
    open var endpointType: EndpointType {
        return .simple
    }
    
    open var simpleEndpoint: EndpointConvertible {
        return NullEndpoint()
    }
    
    open var composedEndpoint: (EndpointConvertible, [String:String]) {
        return (NullEndpoint(), ["":""])
    }
    
    open var method: P3HTTPMethod {
        return .get
    }
    
    open var headerParams: [String:String]? {
        return nil
    }
    
    open var requestBody: [String:Any]? {
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
        
        operationType = .download
        
        super.init()
        
        if downloadConfiguration != .downloadAndSaveToURL {
            fatalError(
                "Trying to initialize download operation" +
                    "with wrong configuration. It should be " +
                    "\(DownloadConfiguration.downloadAndSaveToURL) but is" +
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
        
        operationType = .getData
        
        super.init()
        
        if downloadConfiguration != .downloadAndReturnToParseManually {
            fatalError(
                "Trying to initialize download operation" +
                    "with wrong configuration. It should be " +
                    "\(DownloadConfiguration.downloadAndReturnToParseManually)" +
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
        case .download:
            networkTaskOperation = getDownloadTaskOperationWithRequest(request: (request as NSURLRequest) as URLRequest)
            
        case .getData:
            networkTaskOperation = getDataTaskOperationWithRequest(request: request)
        }
        
        if let op = networkTaskOperation {
            internalQueue.addOperation(op)
        }
    }
    
    open func didDownloadJSON(json: [String:Any]?) {}
    
    open func didDownloadFile(to url: URL?) {}
    
    open func didDownloadData(data: Data?) {}
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
        
        guard
            let data = data,
            let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue),
            let newJsonData = "{\"result\":\(jsonString)}".data(using: String.Encoding.utf8)
            else {
            finish()
            return
        }
        
        downloadedData = newJsonData
        didDownloadData(data: newJsonData)
        
        do {
            let json = try JSONSerialization.jsonObject(with: newJsonData, options: JSONSerialization.ReadingOptions.allowFragments) as? [String:Any]
            self.downloadedJSON = json
            self.didDownloadJSON(json: json)
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
        guard
            let cacheFile = cacheFile,
            let localUrl = url
            else {
                if let error = error {
                    print("error downloading data!: \(error)")
                    finishWithError(error: error as NSError)
                }
                return
        }
        
        do {
            try FileManager.default.removeItem(at: cacheFile)
            try FileManager.default.moveItem(
                at: localUrl,
                to: cacheFile
            )
            
            didDownloadFile(to: cacheFile)
        } catch let error as NSError {
            print("error moving file!: \(error)")
            finishWithError(error: error)
        }
    }
    
    fileprivate func getURL() -> URL? {
        var _url: URL?
        
        if let defaultURL = url {
            _url = defaultURL
        } else {
            switch endpointType {
            case .simple:
                _url = simpleEndpointURL
                
            case .composed:
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
        case .downloadAndReturnToParseManually:
            return ".DownloadAndReturnToParseManually"
            
        case .downloadAndSaveToURL:
            return ".DownloadAndSaveToURL"
        }
    }
}

