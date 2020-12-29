import NIOTransportServices
import NIO

extension NonBlockingFileIO {
    typealias Callback = (_ buffer: ByteBuffer,_ flac: Flac,_ metaType: Int,_ song: Song) -> (Song)
    /// Read the metadata blocks from a flac file
    /// - Parameters:
    ///   - path: The path for the flac file
    ///   - eventLoop: Execute on this eventloop
    ///   - callback: This is to handle the metadata
    /// - Returns: Void
    func metablockReader(path: String,
                         on eventLoop: EventLoop,
                         callback: @escaping Callback) ->
        EventLoopFuture<Song> {
         //let promise = eventLoop.makePromise(of: Song.self)
        
        return self.openFile(path: path,
                      eventLoop: NIOTSEventLoopGroup().next())
            .flatMap { handler, region in
               
                self.isFlac(handler: handler,
                            eventLoop: eventLoop,
                            fileIndex: region.readerIndex)
                .flatMapErrorThrowing { error in
                    print(error)
                    try? handler.close()
                                
                }.flatMap{ _ in
                    self.asyncLoadMeta(
                        handler: handler,
                        eventLoop: eventLoop,
                        fileIndex: region.readerIndex + 4,
                        flac: Flac(),
                        callback: callback)
                }
            }//.cascade(to: promise)
        //return promise.futureResult
    }
        
    func isFlac(handler: NIOFileHandle,
                eventLoop: EventLoop,
                fileIndex: Int) -> EventLoopFuture<Void> {
        return self.read(fileHandle: handler,
                         fromOffset: Int64(fileIndex),
                         byteCount: 4, allocator: .init(),
                         eventLoop: eventLoop)
            .flatMap { data in
                var buffer = data
                if buffer.readString(length: 4) == "fLaC" {
                    return eventLoop.makeSucceededFuture(Void())
                } else {
                    return eventLoop.makeFailedFuture(NonBlockingFileIOReadError.notFlac)
                }
        }
    }
    
    
    func asyncLoadMeta(handler: NIOFileHandle,
                       eventLoop: EventLoop,
                       fileIndex: Int,
                       flac: Flac,
                       song: Song = Song(title: "unknown", artist: "unknown"),
                       callback: @escaping Callback) -> EventLoopFuture<Song> {
        self.read(fileHandle: handler,
                  fromOffset: Int64(fileIndex),
                  byteCount: 4, allocator: .init(),
                  eventLoop: eventLoop)
        .flatMap { byteBuffer -> EventLoopFuture<(ByteBuffer, Flac.Head)> in
            var buffer = byteBuffer
            // TODO: Better error handling
            
            let head = try! flac.readHead(bytes: &buffer)
            let bodyIndex = fileIndex + 4
            return self.read(
                fileHandle: handler,
                fromOffset: Int64(bodyIndex),
                byteCount: head.bodyLength,
                allocator: .init(),
                eventLoop: eventLoop
            ).and(value: head)
        }.flatMap { buffer, head in
            
            let newSong = callback(buffer, flac, head.metaType, song)
            if head.isLast {
                return eventLoop.submit {
                    try? handler.close()
                    return newSong
                }
            } else {
                return self.asyncLoadMeta(
                    handler: handler,
                    eventLoop: eventLoop,
                    fileIndex: fileIndex + 4 + head.bodyLength,
                    flac: flac,
                    song: newSong,
                    callback: callback)
            }
        }
    }
}

enum NonBlockingFileIOReadError: Error {
    case fileReadTimedOut
    case inputTooLong
    case notFlac
}
