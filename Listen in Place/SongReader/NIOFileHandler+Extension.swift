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
        
        self.openFile(path: path, eventLoop: eventLoop)
            .flatMap { handle, region -> EventLoopFuture<ByteBuffer> in
                guard region.readableBytes <= maxBytes else {
                    return eventLoop.makeFailedFuture(NonBlockingFileIOReadError.inputTooLong)
                }
                
                return self.read(fileRegion: region, allocator: .init(), eventLoop: eventLoop)
                    .always { _ in try? handle.close() }
            }.cascade(to: promise)
        
        return promise.futureResult
    }
    
    /// <#Description#>
    /// - Parameters:
    ///   - path: <#path description#>
    ///   - eventLoop: <#eventLoop description#>
    ///   - callback: <#callback description#>
    /// - Returns: <#description#>
    func metablockReader(path: String,
                         on eventLoop: EventLoop,
                         callback: @escaping (_ buffer: ByteBuffer,_ flac: Flac,_ metaType: Int, _ length: Int) -> ()) -> EventLoopFuture<Void> {
        self.openFile(path: path,
                      eventLoop: NIOTSEventLoopGroup().next())
            .map { handler, region in
                
                let flac = Flac()
                
                var fileIndex = region.readerIndex + 4
                var isLast = false
                
                while !isLast {
                    self.read(fileHandle: handler,
                              fromOffset: Int64(fileIndex),
                              byteCount: 4, allocator: .init(),
                              eventLoop: eventLoop)
                        .flatMap { byteBuffer -> EventLoopFuture<(ByteBuffer, Flac.Head)> in
                            var buffer = byteBuffer
                            // TODO: Better error handling
                            let head = try! flac.readHead(bytes: &buffer)
                            fileIndex += 4
                            return self.read(fileHandle: handler,
                                      fromOffset: Int64(fileIndex),
                                      byteCount: head.bodyLength,
                                      allocator: .init(),
                                      eventLoop: eventLoop)
                            .and(value: head)
                        }.whenSuccess { buffer, head in
                            callback(buffer, flac, head.metaType, head.bodyLength)
                            isLast = head.isLast
                            
                            if isLast {
                                try? handler.close()
                            }
                        }
                    
                }
            }
    }
}

enum NonBlockingFileIOReadError: Error {
    case fileReadTimedOut
    case inputTooLong
}
