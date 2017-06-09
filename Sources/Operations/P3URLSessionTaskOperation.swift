//
//  P3URLSessionTaskOperation.swift
//  P3NetworkKit
//
//  Created by Oscar Swanros on 6/19/16.
//  Copyright © 2016 Pacific3. All rights reserved.
//


private var P3URLSessionTaskOperationContext = 0

public class P3URLSessionTaskOperation: P3Operation {
    
    public let task: URLSessionTask
    
    private var observerRemoved = false
    private var stateLock = NSLock()
    
    public init(task: URLSessionTask) {
        assert(task.state == .suspended, "Task must be suspended.")
        self.task = task
        
        super.init()
        
        addObserver(observer: P3OperationBlockObserver(cancelHandler: { _ in task.cancel() }))
    }
    
    override public func execute() {
        assert(task.state == .suspended, "Task was resumed by something other than \(self).")
        
        task.addObserver(
            self,
            forKeyPath: #keyPath(URLSessionTask.state),
            options: NSKeyValueObservingOptions(),
            context: &P3URLSessionTaskOperationContext
        )
        
        task.resume()
    }
    
    

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let object = object as? URLSessionTask, context == &P3URLSessionTaskOperationContext else { return }
        
        stateLock.withCriticalScope {
            if object === task && keyPath == "state" && !observerRemoved {
                switch task.state {
                case .completed:
                    finish()
                    fallthrough
                    
                case .canceling:
                    observerRemoved = true
                    task.removeObserver(self, forKeyPath: #keyPath(URLSessionTask.state))
                    
                default: return
                }
            }
        }
    }
    
//    open override func observeValue(forKeyPath keyPath: String?, of object: AnyObject?, change: [NSKeyValueChangeKey : AnyObject]?, context: UnsafeMutablePointer<Void>?) {
//        guard context == &P3URLSessionTaskOperationContext else { return }
//        
//        stateLock.withCriticalScope(
//            block: {
//                if object === task && keyPath == "state" && !observerRemoved {
//                    switch task.state {
//                    case .completed:
//                        finish()
//                        fallthrough
//                        
//                    case .canceling, .completed:
//                        observerRemoved = true
//                        task.removeObserver(self, forKeyPath: #keyPath(URLSessionTask.state))
//                        
//                    default: return
//                    }
//                }
//            }
//        )
//    }
}

