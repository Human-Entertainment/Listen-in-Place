import NIOTransportServices
import NIO

extension NonBlockingFileIO {
    func readEntireFile(
        _ path: String,
        on eventLoop: EventLoop,
        maxBytes: Int = Int.max,
        timeout: TimeAmount? = nil
    ) -> EventLoopFuture<ByteBuffer> {
        let promise = eventLoop.makePromise(of: ByteBuffer.self)
        
        if let timeout = timeout {
            eventLoop.scheduleTask(in: timeout) {
                promise.fail(NonBlockingFileIOReadError.fileReadTimedOut)
            }
        }
        
        self.openFile(path: path, eventLoop: eventLoop).flatMap { handle, region -> EventLoopFuture<ByteBuffer> in
            guard region.readableBytes <= maxBytes else {
                return eventLoop.makeFailedFuture(NonBlockingFileIOReadError.inputTooLong)
            }
            
            return self.read(fileRegion: region, allocator: .init(), eventLoop: eventLoop)
                .always { _ in try? handle.close() }
        }.cascade(to: promise)
        
        return promise.futureResult
    }
}

extension EventLoopFuture {
    func flatWhen(callback: @escaping (Value) -> EventLoopFuture<Void>) {
        _ = self.flatMap(callback)
    }
}

enum NonBlockingFileIOReadError: Error {
    case fileReadTimedOut
    case inputTooLong
}
