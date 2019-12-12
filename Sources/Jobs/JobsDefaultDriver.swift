import NIO
import Foundation
import Vapor

struct JobsDefaultDriver: JobsDriver {
    func makeQueue(with context: JobContext) -> JobsQueue {
        JobsDefaultQueue(context: context)
    }
    
    func shutdown() {
        // nothing
    }
}

struct JobsDefaultQueue: JobsQueue {
    static var queue: [JobIdentifier] = []
    static var jobs: [JobIdentifier: JobData] = [:]
    static var lock: Lock = .init()
    
    let context: JobContext
    
    func get(_ id: JobIdentifier) -> EventLoopFuture<JobData> {
        JobsDefaultQueue.lock.lock()
        defer { JobsDefaultQueue.lock.unlock() }
        return self.context.eventLoop.makeSucceededFuture(JobsDefaultQueue.jobs[id]!)
    }
    
    func set(_ id: JobIdentifier, to data: JobData) -> EventLoopFuture<Void> {
        JobsDefaultQueue.lock.lock()
        defer { JobsDefaultQueue.lock.unlock() }
        JobsDefaultQueue.jobs[id] = data
        return self.context.eventLoop.makeSucceededFuture(())
    }
    
    func clear(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        JobsDefaultQueue.lock.lock()
        defer { JobsDefaultQueue.lock.unlock() }
        JobsDefaultQueue.jobs[id] = nil
        return self.context.eventLoop.makeSucceededFuture(())
    }
    
    func pop() -> EventLoopFuture<JobIdentifier?> {
        JobsDefaultQueue.lock.lock()
        defer { JobsDefaultQueue.lock.unlock() }
        return self.context.eventLoop.makeSucceededFuture(JobsDefaultQueue.queue.popLast())
    }
    
    func push(_ id: JobIdentifier) -> EventLoopFuture<Void> {
        JobsDefaultQueue.lock.lock()
        defer { JobsDefaultQueue.lock.unlock() }
        JobsDefaultQueue.queue.append(id)
        return self.context.eventLoop.makeSucceededFuture(())
    }
}
