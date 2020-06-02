import NIO
import NIOTransportServices
import Foundation
import UIKit
import Combine

enum SongError: Error {
    case noBookmark
    case coundtReadFile
}

class SongFileCoordinator: NSFileCoordinator {}

struct Song: Hashable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        guard lhs.title == rhs.title else { return false }
        guard lhs.artist == rhs.artist else { return false }
        guard lhs.album == lhs.album else { return false }
        
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
    func load(bookmark data: Data?) throws -> AnyPublisher<Song, SongError> {
        guard let bookmark = data else { throw SongError.noBookmark }
        
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        var loaded: (URL?, Error?) = (nil, nil)
        url.coordinatedRead(SongFileCoordinator()) { inputURL,inputError  in
            loaded = (inputURL, inputError)
        }
        guard let loadURL = loaded.0 else { return Fail<Song, SongError>.init(error: SongError.coundtReadFile ).eraseToAnyPublisher() }
        
        var album: String? = nil
        var artist: String? = nil
        var title: String? = nil
        var cover: UIImage? = nil
        
        let eventLoop = NIOTSEventLoopGroup().next()
        
        let io = NonBlockingFileIO(threadPool: .init(numberOfThreads: 3))
        
        return Future<Song, SongError> { promise in
            io.readEntireFile(loadURL.path,
                              on: eventLoop)
                .whenSuccess { data in
                    var bytes = data
                    let flac = Flac()
                    cover = flac.getFlacAlbum(bytes: &bytes)
                    
                    promise(.success( Song(title: title ?? "Unknow title",
                                artist: artist ?? "Unknown artist",
                                lyrics: nil,
                                album: album ?? "Unknown album",
                                cover: cover ?? UIImage(named: "LP")!,
                                bookmark: bookmark )
                    ))
            }
        }.eraseToAnyPublisher()
        
        
        
        // TODO: make it so MP3 can also be parsed
    }
}

extension Notification.Name {
    static let newSong = Notification.Name("New Song")
}
