import Foundation
import NIO
import NIOTransportServices

// From https://github.com/palmin/open-in-place/blob/master/OpenInPlace/UrlCoordination.swift
extension URL {
    public func coordinatedRead(coordinator : NSFileCoordinator) async throws -> URL {

        let error: NSErrorPointer = nil
           
        return try await withUnsafeThrowingContinuation{ continuation in
            coordinator
                .coordinate(readingItemAt: self,
                            options: [],
                            error: error,
                            byAccessor: { url in
                                if let error = error as? Error {
                                    continuation.resume(with: .failure(error))
                                } else {
                                    continuation.resume(with: .success(url))
                                }
                            })
        }
    }
}
