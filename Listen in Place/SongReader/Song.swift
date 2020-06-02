import NIO
import NIOTransportServices
import Foundation
import UIKit
import Combine

enum SongError: Error {
    case noBookmark
    case coundtReadFile
}

struct Song: Hashable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        guard lhs.title == rhs.title &&
              lhs.artist == rhs.artist &&
              lhs.album == rhs.album &&
              lhs.cover == rhs.cover else { return false }
        
        return true
    }
    
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

struct SongPublisher {
    private let threadPool: NIOThreadPool
    
    init(threadPool: NIOThreadPool)
    {
        self.threadPool = threadPool
    }
    
    func load(bookmark data: Data?) throws -> Future<Song, SongError> {
        guard let bookmark = data else { throw SongError.noBookmark }
        
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        // TODO: Add Coordinator
        /*
        var loaded: (URL?, Error?) = (nil, nil)
        let coordinator = NSFileCoordinator()
        url.coordinatedRead(coordinator) { inputURL,inputError  in
            loaded = (inputURL, inputError)
        }
        guard let loadURL = loaded.0 else { return Fail<Song, SongError>.init(error: SongError.coundtReadFile ).eraseToAnyPublisher() }
        */
        
        return Future<Song, SongError> { promise in
            self.threadPool.start()
            let loaded = self.asyncLoad(url: url, bookmark: bookmark)
            loaded.whenSuccess { song in
                promise(.success(song))
            }
            loaded.whenFailure { error in
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
        
        let eventLoop = NIOTSEventLoopGroup().next()
        
        return NonBlockingFileIO(threadPool: self.threadPool)
            .metablockReader(path: url.path,
                             on: eventLoop) { data, flac, type, length  in
                                var bytes = data
                                switch type {
                                    case 6:
                                        guard let picture = try? Picture(bytes: &bytes) else { return }
                                        if picture.pictureType == .CoverFront {
                                            cover = picture.image
                                        } else {
                                            print(picture.mimeType)
                                        }
                                    break
                                    default:
                                        print("Couldn't parse block")
                                        break
                                }
            }.flatMapResult { () -> Result<Song, SongError> in
                let song = Song(title: title ?? "Unknow title",
                                artist: artist ?? "Unknown artist",
                                lyrics: nil,
                                album: album ?? "Unknown album",
                                cover: cover ?? UIImage(named: "LP")!,
                                bookmark: bookmark )
                return .success(song)
            }
       
    }


}



extension Notification.Name {
    static let newSong = Notification.Name("New Song")
}
