import NIO
import NIOTransportServices
import Foundation
#if os(iOS)
import UIKit
#endif
import Combine

enum SongError: Error {
    case noBookmark
    case coundtReadFile
}

struct Song {
    private(set) var title: String = ""
    private(set) var artist: String = ""
    private(set) var lyrics: String? = nil
    private(set) var cover: UIImage = UIImage(named: "LP")!
    private(set) var album: String? = nil
    private(set) var bookmark: Data? = nil
    
    init(title: String,
         artist: String,
         lyrics: String? = nil,
         album: String? = nil,
         cover: UIImage? = nil,
         bookmark: Data? = nil)
    {
        self.title = title
        self.artist = artist
        self.lyrics = lyrics
        self.album = album
        self.cover = cover ?? UIImage(named: "LP")!
        self.bookmark = bookmark
    }
    
    
}

extension Song: Hashable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        guard lhs.title == rhs.title &&
                lhs.artist == rhs.artist &&
                lhs.album == rhs.album &&
                lhs.cover == rhs.cover else { return false }
        
        return true
    }
}

extension Song: Identifiable {
    var id: ObjectIdentifier {
        .init(cover)
    }
}

struct SongPublisher {
    private let threadPool: NIOThreadPool
    
    private let eventLoop: EventLoop
    
    init(threadPool: NIOThreadPool,
         on eventLoop: EventLoop = NIOTSEventLoopGroup().next())
    {
        self.threadPool = threadPool
        self.eventLoop = eventLoop
    }
    
    func load(url: URL, bookmark: Data) throws -> Future<Song, SongError> {
        Future<Song, SongError> { promise in
            
            let coordinator = url.coordinatedRead(coordinator: NSFileCoordinator(),
                                on: eventLoop)
            coordinator.whenSuccess { url in
                
                self.threadPool.start()
                let loaded = self.asyncLoad(url: url, bookmark: bookmark)
                loaded.whenSuccess { song in
                    promise(.success(song))
                }
                loaded.whenFailure { error in
                    
                    print(error)
                    promise(.failure(.coundtReadFile))
                }
            }
            coordinator.whenFailure { error in
                promise(.failure(.coundtReadFile))
            }
        }
        
        // TODO: make it so MP3 can also be parsed
    }
    
    private func asyncLoad(url: URL, bookmark: Data) -> EventLoopFuture<Song> {
        var album: String? = nil
        var artist: String? = nil
        var title: String? = nil
        var cover: UIImage? = nil
        
        return NonBlockingFileIO(threadPool: self.threadPool)
            .metablockReader(path: url.path,
                             on: eventLoop)
            { data, flac, type  in
                var bytes = data
                switch type {
                    case 0:
                        print("Streaminfro block")
                        break
                    case 1:
                        print("Padding block")
                    break
                    case 2:
                        print("Application block")
                    break
                    case 3:
                        print("Seekable block")
                    break
                    case 4:
                        print("Vorbis comment block")
                        guard let vorbis = try? VorbisComment(bytes: &bytes) else { return }
                        
                        artist = vorbis.artist // comments["artist"]
                        album = vorbis.album // comments["album"]
                        title = vorbis.title //comments["title"]
                        print(vorbis)
                    break
                    case 5:
                        print("Cuesheet")
                    break
                    case 6:
                        print("Image")
                        do {
                            let picture = try Picture(bytes: &bytes)
                            
                            if picture.pictureType == .CoverFront {
                                cover = picture.image
                                print(cover as Any)
                            } else {
                                print(picture.mimeType)
                            }
                        } catch {
                            print("Image loading issue \(error)")
                        }
                        break
                    default:
                        assertionFailure("Heck?")
                        break
                }
        }.map { _ -> Song in
                // TODO: Figure out of how to load this together with the rest of the async stuff
                let song = Song(title: title ?? "Unknow title",
                                artist: artist ?? "Unknown artist",
                                lyrics: nil,
                                album: album ?? "Unknown album",
                                cover: cover ?? UIImage(named: "LP")!,
                                bookmark: bookmark)
                return song
        }.flatMapErrorThrowing { error in
            print(error)
            let avEnum = PlayerEnum.AVPlayer(.init(url: url), url)
            return avEnum.getSong()
        }
       
    }


}



extension Notification.Name {
    static let newSong = Notification.Name("New Song")
}
