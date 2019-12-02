import Foundation
import Vapor
import NIO

/// A provider used to setup the `Jobs` package
public struct JobsProvider: Provider {
    /// The key to use for calling the command. Defaults to `jobs`
    public var commandKey: String
    
    /// Initializes the `Jobs` package
    public init(commandKey: String = "jobs") {
        self.commandKey = commandKey
    }

    /// See `Provider`.`register(_ app:)`
    public func register(_ app: Application) {
        app.register(JobsService.self) { app in
            return ApplicationJobsService(
                configuration: app.make(),
                driver: app.make(),
                logger: app.make(),
                eventLoopPreference: .indifferent
            )
        }

        app.register(JobsConfiguration.self) { _ in
            return JobsConfiguration(application: app)
        }

        app.register(instance: JobsQueue.default)

        app.register(JobsDriver.self) { app in
            return JobsDefaultDriver(on: app.make())
        }

        app.register(JobsWorker.self) { app in
            return .init(configuration: app.make(),
                         driver: app.make(),
                         logger: app.make(),
                         on: app.make())
        }

        app.register(singleton: ScheduledJobsWorker.self) { app in
            return .init(configuration: app.make(),
                         logger: app.make(),
                         on: app.make())
        }
        
        app.register(singleton: JobsCommand.self, boot: { app in
            return .init(application: app)
        }, shutdown: { jobs in
            jobs.shutdown()
        })
        
        app.register(extension: CommandConfiguration.self) { configuration, a in
            configuration.use(a.make(JobsCommand.self), as: self.commandKey)
        }
    }
    
    public func didBoot(_ app: Application) throws {
        let worker = app.make(JobsWorker.self)
        worker.start(on: app.make())

        let sworker = app.make(ScheduledJobsWorker.self)
        try sworker.start()
    }

    public func willShutdown(_ app: Application) {
        let worker = app.make(JobsWorker.self)
        worker.shutdown()

        let sworker = app.make(ScheduledJobsWorker.self)
        sworker.shutdown()
    }
}

public struct ApplicationJobs {
    private let application: Application
    
    public init(for application: Application) {
        self.application = application
    }
    
    public func add<J>(_ job: J) where J: Job {
        application.register(extension: JobsConfiguration.self) { jobs, app in
            jobs.add(job)
        }
    }
    
    public func driver(_ driver: JobsDriver) {
        application.register(instance: driver)
    }
    
    public func schedule<J>(_ job: J) -> ScheduleBuilder
        where J: ScheduledJob
    {
        let builder = ScheduleBuilder()
        application.register(extension: JobsConfiguration.self) { jobs, app in
            _ = jobs.schedule(job, builder: builder)
        }
        return builder
    }
}

extension Application {
    public var jobs: ApplicationJobs {
        return ApplicationJobs(for: self)
    }
}
