//
//  UIImageView.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/19/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//

public let kP3NKDidFinishSettingImageFromURLToImageView = "kP3NKDidFinishSettingImageFromURLToImageView"

private func imageCacheKey(request: NSURLRequest) -> String {
    return request.url?.absoluteString ?? ""
}

public protocol ImageCaching {
    func cachedImage(request: NSURLRequest) -> UIImage?
    func cache(image: UIImage, for request: NSURLRequest)
}

private class ImageCache: NSCache<AnyObject, AnyObject>, ImageCaching {
    fileprivate func cache(image: UIImage, for request: NSURLRequest) {
        setObject(image, forKey: imageCacheKey(request: request) as AnyObject)
    }
    
    fileprivate func cachedImage(request: NSURLRequest) -> UIImage? {
        switch request.cachePolicy {
        case .reloadIgnoringLocalCacheData, .reloadIgnoringLocalAndRemoteCacheData:
            return nil
            
        default:
            break
        }
        
        return object(forKey: imageCacheKey(request: request) as AnyObject) as? UIImage
    }
}

private var OperationAssociatedObjectKey: UInt8 = 0
private let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
private let operationQueue = P3OperationQueue()

public extension UIImageView {
    private static let p3_sharedImageCache = ImageCache()
    
    private var imageRequestOperation: P3Operation? {
        get {
            return objc_getAssociatedObject(self, &OperationAssociatedObjectKey) as? P3Operation
        }
        
        set {
            objc_setAssociatedObject(self, &OperationAssociatedObjectKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func p3_setImage(request: URLRequest, placeholder: UIImage?) {
        if let cachedImage = UIImageView.p3_sharedImageCache.cachedImage(request: request as NSURLRequest) {
            image = cachedImage
            imageRequestOperation = nil
            postNotification()
        } else {
            if let placeholder = placeholder {
                image = placeholder
            }
            
            let task = session.dataTask(with: request) { [weak self] data, response, error in
                p3_executeOnMainThread {
                    guard
                        let strongSelf = self,
                        let data = data,
                        let serializedImage = UIImage(data: data)
                        else {
                            return
                    }
                    
                    UIView.transition(
                        with: strongSelf,
                        duration: 0.3,
                        options: .transitionCrossDissolve,
                        animations: {
                            strongSelf.image = serializedImage
                        }, completion: { finished in
                            if finished {
                                strongSelf.postNotification()
                            }
                        }
                    )
                    
                    UIImageView.p3_sharedImageCache.cache(image: serializedImage, for: request as NSURLRequest)
                }
            }
            
            imageRequestOperation = P3URLSessionTaskOperation(task: task)
            #if os(iOS)
                imageRequestOperation?.addObserver(observer: P3NetworkActivityObserver())
            #endif
            operationQueue.addOperation(imageRequestOperation!)
        }
    }
    
    public func p_cancelImageRequestOperation() {
        guard let operation = imageRequestOperation else {
            return
        }
        
        operation.cancel()
    }
    
    public func p_setImageWithURL(url: URL) {
        p3_setImage(url: url, placeholder: nil)
    }
    
    public func p3_setImage(url: URL, placeholder: UIImage?) {
        var request = URLRequest(url: url)
        request.addValue("image/*", forHTTPHeaderField: "Accept")
        request.cachePolicy = .returnCacheDataElseLoad
        
        
        p3_setImage(request: request, placeholder: placeholder)
    }
    
    private func postNotification() {
        p3_executeOnMainThread {
            NotificationCenter.default.post(
                name: NSNotification.Name(
                    rawValue: kP3NKDidFinishSettingImageFromURLToImageView
                ),
                object: nil
            )
        }
    }
}


