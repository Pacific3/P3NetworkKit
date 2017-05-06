//
//  P3ImageCache.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 5/6/17.
//  Copyright © 2017 Pacific3. All rights reserved.
//

public typealias ImageCacheIdentifier = String

public protocol ImageCaching {
    func cachedImage(request: URLRequest) -> UIImage?
    func cache(image: UIImage, for request: URLRequest)
}

final public class P3ImageCache: NSCache<AnyObject, AnyObject>, ImageCaching {
    private let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
    private let operationQueue = P3OperationQueue()
    private var downloadingOperations: [String:P3Operation] = [:]
    
    public static let sharedImageCache = P3ImageCache()
    
    // MARK: - Keys
    public func imageCacheKey(request: URLRequest) -> ImageCacheIdentifier {
        guard let url = request.url else {
            return ""
        }
        
        return imageCacheKey(url: url)
    }
    
    public func imageCacheKey(url: URL) -> ImageCacheIdentifier {
        return url.absoluteString
    }
    
    
    // MARK: - Getting from cache
    public func cachedImage(request: URLRequest) -> UIImage? {
        switch request.cachePolicy {
        case .reloadIgnoringLocalCacheData, .reloadIgnoringLocalAndRemoteCacheData:
            return nil
            
        default:
            break
        }
        
        return cachedImage(id: imageCacheKey(request: request))
    }
    
    public func cachedImage(url: URL) -> UIImage? {
        return cachedImage(id: imageCacheKey(url: url))
    }
    
    private func cachedImage(id: ImageCacheIdentifier) -> UIImage? {
        return object(forKey: id as AnyObject) as? UIImage
    }
    
    
    // MARK: - Adding to cache
    public func cache(image: UIImage, for request: URLRequest) {
        setObject(image, forKey: imageCacheKey(request: request) as AnyObject)
    }
    
    public func cache(image: UIImage, url: URL) {
        setObject(image, forKey: imageCacheKey(url: url) as AnyObject)
    }
    
    public func cache(image: UIImage, string: String) {
        setObject(image, forKey: string as AnyObject)
    }
    
    @discardableResult
    public func downloadImageWithURLToCache(url: URL, completion: ((UIImage?) -> Void)?) -> ImageCacheIdentifier {
        let request = imageRequestForURL(url: url)
        let id = imageCacheKey(request: request)
        
        let task = session.dataTask(with: request) { data, response, error in
            self.downloadingOperations.removeValue(forKey: id)
            
            guard
                let data = data,
                let serializedImage = UIImage(data: data)
                else {
                    completion?(nil)
                    return
            }
            
            P3ImageCache.sharedImageCache.cache(image: serializedImage, for: request)
            completion?(serializedImage)
        }
        
        let imageRequestOperation = P3URLSessionTaskOperation(task: task)
        #if os(iOS)
            imageRequestOperation.addObserver(observer: P3NetworkActivityObserver())
        #endif
        downloadingOperations[id] = imageRequestOperation
        operationQueue.addOperation(imageRequestOperation)
        return id
    }
    
    
    // MARK: - Misc
    public func cancelDownloadWithIdentifier(id: ImageCacheIdentifier) {
        if let op = downloadingOperations[id] {
            op.cancel()
        }
        
        downloadingOperations[id] = nil
    }
    
    
    // MARK: - Private methods
    private func imageRequestForURL(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue("image/*", forHTTPHeaderField: "Accept")
        request.cachePolicy = .returnCacheDataElseLoad
        return request
    }
}
