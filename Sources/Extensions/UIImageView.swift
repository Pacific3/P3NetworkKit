//
//  UIImageView.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/19/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//

public let kP3NKDidFinishSettingImageFromURLToImageView = "kP3NKDidFinishSettingImageFromURLToImageView"
private var CacheIdentifierObjectKey: UInt8 = 0

public extension UIImageView {
    private var downloadingOperationIdentifier: ImageCacheIdentifier? {
        get {
            return objc_getAssociatedObject(self, &CacheIdentifierObjectKey) as? ImageCacheIdentifier
        }
        
        set {
            objc_setAssociatedObject(self, &CacheIdentifierObjectKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public func p3_cancelImageRequestOperation() {
        guard let id = downloadingOperationIdentifier else { return }
        
        P3ImageCache.sharedImageCache.cancelDownloadWithIdentifier(id: id)
        downloadingOperationIdentifier = nil
    }
    
    public func p3_setImageWithURL(url: URL) {
        p3_setImage(url: url, placeholder: nil)
    }
    
    public func p3_setImage(url: URL, placeholder: UIImage?) {
        if let cachedImage = P3ImageCache.sharedImageCache.cachedImage(url: url) {
            image = cachedImage
            postNotification()
        } else {
            if let placeholder = placeholder {
                image = placeholder
            }
            
            downloadingOperationIdentifier = P3ImageCache.sharedImageCache.downloadImageWithURLToCache(url: url, completion: { [weak self] image in
                p3_executeOnMainThread {
                    self?.downloadingOperationIdentifier = nil
                    
                    guard
                        let strongSelf = self,
                        let image = image
                        else { return }
                    
                    UIView.transition(
                        with: strongSelf,
                        duration: 0.3,
                        options: .transitionCrossDissolve,
                        animations: {
                            strongSelf.image = image
                    }, completion: { (finished) in
                        if finished {
                            strongSelf.postNotification()
                        }
                    })
                }
            })
        }
    }
    
    
    // MARK: - Private methods
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


