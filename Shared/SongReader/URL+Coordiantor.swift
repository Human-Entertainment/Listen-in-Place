import Foundation
import NIO
import NIOTransportServices

// From https://github.com/palmin/open-in-place/blob/master/OpenInPlace/UrlCoordination.swift
extension URL {
    public func coordinatedRead(coordinator : NSFileCoordinator,
                                on eventLoop: EventLoop) -> EventLoopFuture<URL> {
        let promise = eventLoop.makePromise(of: URL.self)
        
        eventLoop.execute {
            let error: NSErrorPointer = nil
            coordinator
                .coordinate(readingItemAt: self,
                            options: [],
                            error: error,
                            byAccessor: { url in
                                if let error = error as? Error {
                                    promise.fail(error)
                                } else {
                                    promise.succeed(url)
                                }
                            })
        }
        
        return promise.futureResult
    }
}
