import NIO
import NIOTransportServices
import Foundation
import Combine

enum SongError: Error {
    case noBookmark
    case coundtReadFile
}

struct Song {
    private(set) var title: String = ""
    private(set) var artist: String = ""
    private(set) var lyrics: String? = nil
    private(set) var cover: Data? = nil
    private(set) var album: String? = nil
    private(set) var bookmark: Data? = nil
    private(set) var tracknumber: String? = nil
    
    init(title: String,
         artist: String,
         tracknumber: String? = nil,
         lyrics: String? = nil,
         album: String? = nil,
         cover: Data? = nil,
         bookmark: Data? = nil)
    {
        self.title = title
        self.artist = artist
        self.lyrics = lyrics
        self.album = album
        self.cover = cover
        self.bookmark = bookmark
        self.tracknumber = tracknumber
    }
    
    
}

extension Song: Identifiable {
    var id: String {
        (album ?? "Unknown") + (tracknumber ?? "0")
    }
}

extension Song: Hashable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.cover == rhs.cover
    }
}

struct SongPublisher {
    private let threadPool: NIOThreadPool
    
    private let eventLoop: EventLoop
    
    init(threadPool: NIOThreadPool)
    {
        self.threadPool = threadPool
        self.eventLoop = NIOTSEventLoopGroup().next()
    }
    
    func load(url: URL, bookmark: Data) throws -> Future<Song, SongError> {
        Future<Song, SongError> { promise in
            
            let coordinator = url.coordinatedRead(coordinator: NSFileCoordinator(),
                                on: eventLoop)
            coordinator.whenSuccess { url in
                
                self.threadPool.start()
                self.asyncLoad(
                    bookmark: bookmark,
                    url: url,
                    threadPool: self.threadPool
                ).whenComplete { result in
                    switch (result) {
                        case let .failure(error):
                            print(error)
                            promise(.failure(.coundtReadFile))
                            break
                        case let .success(song):
                            promise(.success(song))
                            break
                    }
                
                }
            }
            coordinator.whenFailure { error in
                promise(.failure(.coundtReadFile))
            }
        }
        
        // TODO: make it so MP3 can also be parsed
    }
    
    private func asyncLoad(
        bookmark: Data,
        url: URL,
        threadPool: NIOThreadPool) -> EventLoopFuture<Song> {
        
        return NonBlockingFileIO(threadPool: threadPool)
            .metablockReader(
                path: url.path,
                on: eventLoop
            ) { data, flac, type, song  in
                var bytes = data
                switch type {
                    case 0:
                        print("Streaminfro block")
                        return song
                    case 1:
                        print("Padding block")
                        return song
                    case 2:
                        print("Application block")
                        return song
                    case 3:
                        print("Seekable block")
                        return song
                    case 4:
                        print("Vorbis comment block")
                        guard let vorbis = try? VorbisComment(bytes: &bytes) else { return song }
                        print(vorbis)
                        return Song (
                            title: vorbis.title ?? song.title,
                            artist: vorbis.artist ?? song.artist,
                            tracknumber: vorbis.tracknumber,
                            lyrics: song.lyrics,
                            album: vorbis.album,
                            cover: song.cover,
                            bookmark: bookmark
                        )
                    case 5:
                        print("Cuesheet")
                        return song
                    case 6:
                        print("Image")
                        do {
                            let picture = try Picture(bytes: &bytes)
                            
                            if picture.pictureType == .CoverFront {
                                let cover = picture.image
                                print(cover as Any)
                                return Song (
                                    title: song.title,
                                    artist: song.artist,
                                    tracknumber: song.tracknumber,
                                    lyrics: song.lyrics,
                                    album: song.album,
                                    cover: cover,
                                    bookmark: bookmark
                                )
                            } else {
                                print(picture.mimeType)
                                return song
                            }
                        } catch {
                            print("Image loading issue \(error)")
                            return song
                        }
                    default:
                        assertionFailure("Heck?")
                        return song
                }
        }.flatMapErrorThrowing { error in
            print(error)
            if error as? NonBlockingFileIOReadError == NonBlockingFileIOReadError.notFlac {
                // Fallback for when the song metadata isn't supported
                let avEnum = PlayerEnum.AVPlayer(.init(url: url), url)
                return avEnum.getSong()
            } else {
                throw error
            }
        }
       
    }


}
