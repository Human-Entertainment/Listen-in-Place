import NIOTransportServices
import NIO
import AsyncKit

extension NonBlockingFileIO {
    /// Read the metadata blocks from a flac file
    /// - Parameters:
    ///   - path: The path for the flac file
    ///   - on: The eventloop to execute on
    /// - Returns: Void
    func metablockReader(path: String,
                         on eventLoop: EventLoop) async throws -> AsyncThrowingStream<(buffer: ByteBuffer, metaType: Int), any Swift.Error> {
        
        let (handler, region) = try await self.openFile(path: path,
                                               eventLoop: eventLoop).get()
            
        guard await isFlac(handler: handler, eventLoop: eventLoop, fileIndex: region.readerIndex) else {
            try handler.close()
            throw NonBlockingFileIOReadError.notFlac
        }
            
        return try await asyncLoadMeta(
                    handler: handler,
                    eventLoop: eventLoop,
                    fileIndex: region.readerIndex + 4)
    }
    
    func isFlac(handler: NIOFileHandle, eventLoop: EventLoop, fileIndex: Int) async -> Bool {
        
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
   
    /// Iterates over each item in the header. Callsite should handle this.
    /// - Parameters:
    ///   - handler: File handle to read. Please not that this will be closed when the meta datas are done being read, so remember to open it again if you need to read more data.
    ///   - eventLoop: The eventloop to execute on.
    ///   - fileIndex: The place in the file to index from.
    ///   - flac: I don't know
    func asyncLoadMeta(handler: NIOFileHandle,
                       eventLoop: EventLoop,
                       fileIndex startIndex: Int,
                       flac: Flac = .init()) async throws -> AsyncThrowingStream<(buffer: ByteBuffer, metaType: Int), any Swift.Error> {
        print("STREAMS")
        
        return AsyncThrowingStream { continuation in
            print("New Stream")
            Task {
                defer {
                    continuation.finish()
                    try! handler.close()
                }
                
                var isLast = false
                var index = startIndex
                while (!isLast) {
                    var buff = try await self.read(
                        fileHandle: handler,
                        fromOffset: Int64(index),
                        byteCount: 4,
                        allocator: .init(),
                        eventLoop: eventLoop
                    ).get()
                    
                    let head = try flac.readHead(bytes: &buff)
                    isLast = head.isLast
                    let bodyIndex = index + 4
                    
                    let body = try await self.read(
                        fileHandle: handler,
                        fromOffset: Int64(bodyIndex),
                        byteCount: head.bodyLength,
                        allocator: .init(),
                        eventLoop: eventLoop
                    ).get()
                    
                    continuation.yield((buffer: body, metaType: head.metaType))
                    index += 4 + head.bodyLength
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
