import NIOTransportServices
import NIO
import AsyncKit

extension NonBlockingFileIO {
       /// Read the metadata blocks from a flac file
    /// - Parameters:
    ///   - path: The path for the flac file
    ///   - eventLoop: Execute on this eventloop
    ///   - callback: This is to handle the metadata
    /// - Returns: Void
    func metablockReader(path: String,
                         on eventLoop: EventLoop) async throws -> AsyncThrowingStream<(buffer: ByteBuffer, metaType: Int), any Swift.Error> {
        
        let (handler, region) = try await self.openFile(path: path, eventLoop: eventLoop).get()
            
        guard await isFlac(handler: handler, eventLoop: eventLoop, fileIndex: region.readerIndex) else {
            try handler.close()
            throw NonBlockingFileIOReadError.notFlac
        }
            
        return try await asyncLoadMeta(
                    handler: handler,
                    eventLoop: eventLoop,
                    fileIndex: region.readerIndex + 4,
                    flac: Flac())
    }
    
    func isFlac(handler: NIOFileHandle,
                eventLoop: EventLoop,
                fileIndex: Int) async -> Bool {
        let buffer: ByteBuffer = await withCheckedContinuation { continuation in
            let _ = self.readChunked(fileHandle: handler,
                                     byteCount: 4,
                                     allocator: .init(),
                                     eventLoop: eventLoop) { buffer in
                continuation.resume(returning: buffer)
                return eventLoop.makeSucceededFuture(Void())
            }
        }

        return buffer.getString(at: buffer.readerIndex, length: 4) == "fLaC"
    }
   
    func asyncLoadMeta(handler: NIOFileHandle,
                       eventLoop: EventLoop,
                       fileIndex: Int,
                       flac: Flac) async throws -> AsyncThrowingStream<(buffer: ByteBuffer, metaType: Int), any Swift.Error> {
        
        defer { try? handler.close() }
        
        return AsyncThrowingStream { continuation in
            Task {
                var isLast = false
                while (!isLast) {
                    var buff = try await self.read(
                        fileHandle: handler,
                        fromOffset: Int64(fileIndex),
                        byteCount: 4,
                        allocator: .init(),
                        eventLoop: eventLoop
                    ).get()
                    
                    let head = try flac.readHead(bytes: &buff)
                    isLast = head.isLast
                    let bodyIndex = fileIndex + 4
                    
                    let body = try await self.read(
                        fileHandle: handler,
                        fromOffset: Int64(bodyIndex),
                        byteCount: head.bodyLength,
                        allocator: .init(),
                        eventLoop: eventLoop
                    ).get()
                    
                    continuation.yield((buffer: buff, metaType: head.metaType))
                }
            }
        }
    }
}

enum NonBlockingFileIOReadError: Error {
    case fileReadTimedOut
    case inputTooLong
    case notFlac
}
