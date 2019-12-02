import NIO
import Foundation
import Vapor

/// A wrapper that conforms to `JobsPersistenceLayer`
public struct JobsDefaultDriver: JobsDriver {

    public var eventLoopGroup: EventLoopGroup

    let logger: Logger
    
    static var lock: Lock = Lock()
    static var storage: [String: [JobStorage]] = [:]
    
    public init(on eventLoopGroup: EventLoopGroup) {
        self.eventLoopGroup = eventLoopGroup
        self.logger = Logger(label: "codes.vapor.jobs-default-driver")
    }

    /// Returns a `JobData` wrapper for a specified key.
    ///
    /// - Parameters:
    ///   - key: The key that the data is stored under.
    /// - Returns: The retrieved `JobStorage`, if it exists.
    public func get(key: String, eventLoop: JobsEventLoopPreference) -> EventLoopFuture<JobStorage?> {
        
        guard let kval = JobsDefaultDriver.storage[key], !kval.isEmpty else {
            return eventLoop.delegate(for: self.eventLoopGroup).makeSucceededFuture(nil)
        }
        
        var result: JobStorage!
        JobsDefaultDriver.lock.withLockVoid {
            result = JobsDefaultDriver.storage[key]!.remove(at: 0)
        }
        return eventLoop.delegate(for: self.eventLoopGroup).makeSucceededFuture(result)
    }
    
    /// Handles adding a `Job` to the persistence layer for future processing.
    ///
    /// - Parameters:
    ///   - key: The key to add the `Job` under.
    ///   - jobStorage: The `JobStorage` object to persist.
    /// - Returns: A future `Void` value used to signify completion
    public func set(key: String, job jobStorage: JobStorage, eventLoop: JobsEventLoopPreference) -> EventLoopFuture<Void> {
        JobsDefaultDriver.lock.withLockVoid {
            if !JobsDefaultDriver.storage.keys.contains(key) {
                JobsDefaultDriver.storage[key] = []
            }
            JobsDefaultDriver.storage[key]!.append(jobStorage)
        }
        return eventLoop.delegate(for: self.eventLoopGroup).makeSucceededFuture(())
    }
    
    /// Called upon completion of the `Job`. Should be used for cleanup.
    ///
    /// - Parameters:
    ///   - key: The key that the `Job` was stored under
    ///   - jobStorage: The jobStorage holding the `Job` that was completed
    /// - Returns: A future `Void` value used to signify completion
    public func completed(key: String, job jobStorage: JobStorage, eventLoop: JobsEventLoopPreference) -> EventLoopFuture<Void> {
        return eventLoop.delegate(for: self.eventLoopGroup).makeSucceededFuture(())
    }
    
    /// Returns the processing version of the key
    ///
    /// - Parameter key: The base key
    /// - Returns: The processing key
    public func processingKey(key: String) -> String {
        return key + "-processing"
    }
    
    /// Requeues a job due to a delay
    /// - Parameter key: The key of the job
    /// - Parameter jobStorage: The jobStorage holding the `Job` to be requeued
    public func requeue(key: String, job jobStorage: JobStorage, eventLoop: JobsEventLoopPreference) -> EventLoopFuture<Void> {
        JobsDefaultDriver.lock.withLockVoid {
            if !JobsDefaultDriver.storage.keys.contains(key) {
                JobsDefaultDriver.storage[key] = []
            }
            JobsDefaultDriver.storage[key]!.insert(jobStorage, at: 1)
        }
        return eventLoop.delegate(for: self.eventLoopGroup).makeSucceededFuture(())
    }
}
