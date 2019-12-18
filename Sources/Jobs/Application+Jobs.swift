import Foundation
import Vapor
import NIO

extension Application {
    public var jobs: Jobs {
        .init(application: self)
    }
    
    public struct Jobs {
        public struct Provider {
            let run: (Application) -> ()

            public init(_ run: @escaping (Application) -> ()) {
                self.run = run
            }
        }

        final class Storage {
            public var configuration: JobsConfiguration
            let command: JobsCommand
            var driver: JobsDriver?

            public init(_ application: Application) {
                self.configuration = .init(application: application, logger: application.logger)
                self.command = .init(application: application)
                application.commands.use(self.command, as: "jobs")
                self.driver = JobsDefaultDriver()
            }

        }

        struct Key: StorageKey {
            typealias Value = Storage
        }

        struct Lifecycle: LifecycleHandler {
            func willBoot(_ application: Application) throws {
                struct Signature: CommandSignature {
                    @Option(name: "queue", help: "If set, Jobs will automatically run queue on boot")
                    var queue: String?

                    @Flag(name: "auto-schedule", help: "If true, Jobs will automatically run schedule jobs on boot")
                    var autoSchedule: Bool

                    init() { }
                }

                let signature = try Signature(from: &application.environment.commandInput)
                if signature.autoSchedule {
                    application.logger.info("Starting scheduled jobs worker")
                    try application.jobs.storage.command.startScheduledJobs()
                }
                let queue: JobsQueueName = signature.queue.flatMap { .init(string: $0) } ?? .default
                application.logger.info("Starting jobs worker (queue: \(queue.string))")
                try application.jobs.storage.command.startJobs(on: queue)
            }

            func shutdown(_ application: Application) {
                application.jobs.storage.command.shutdown()
                if let driver = application.jobs.storage.driver {
                    driver.shutdown()
                }
            }
        }

        public var configuration: JobsConfiguration {
            get { self.storage.configuration }
            nonmutating set { self.storage.configuration = newValue }
        }

        public var queue: JobsQueue {
            self.queue(.default)
        }

        public var driver: JobsDriver {
            guard let driver = self.storage.driver else {
                fatalError("No Jobs driver configured. Configure with app.jobs.use(...)")
            }
            return driver
        }

        var storage: Storage {
            if self.application.storage[Key.self] == nil {
                self.initialize()
            }
            return self.application.storage[Key.self]!
        }

        let application: Application

        public func queue(
            _ name: JobsQueueName,
            logger: Logger? = nil,
            on eventLoop: EventLoop? = nil
        ) -> JobsQueue {
            return self.driver.makeQueue(
                with: .init(
                    queueName: name,
                    configuration: self.configuration,
                    logger: logger ?? self.application.logger,
                    on: eventLoop ?? self.application.eventLoopGroup.next()
                )
            )
        }

        public func add<J>(_ job: J) where J: Job {
            self.configuration.add(job)
        }

        public func use(_ provider: Provider) {
            provider.run(self.application)
        }

        public func use(custom driver: JobsDriver) {
            self.storage.driver = driver
        }

        public func schedule<J>(_ job: J) -> ScheduleBuilder
            where J: ScheduledJob
        {
            let builder = ScheduleBuilder()
            _ = self.storage.configuration.schedule(job, builder: builder)
            return builder
        }

        func initialize() {
            self.application.lifecycle.use(Lifecycle())
            self.application.storage[Key.self] = .init(application)
        }
    }
}
