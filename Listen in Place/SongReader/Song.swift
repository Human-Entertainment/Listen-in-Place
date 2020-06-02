import NIO
import NIOTransportServices
import Foundation
import UIKit

enum SongError: Error {
    case noBookmark
}
class Song: NSFileCoordinator {
    private(set) var title: String = ""
    private(set) var artist: String = ""
    private(set) var lyrics: String? = nil
    private(set) var cover: UIImage = UIImage(named: "LP")!
    private(set) var album: String? = nil
    private(set) var bookmark: Data? = nil
    
    func load(title: String,
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
    
    func load(bookmark data: Data?) throws {
        guard let bookmark = data else { throw SongError.noBookmark }
        
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        self.load(url: url, bookmark: bookmark)
    }
    
    func load(url: URL, bookmark: Data? = nil) {
        
        var album: String? = nil
        var artist: String? = nil
        var title: String? = nil
        var cover: UIImage? = nil
        
        let eventLoop = NIOTSEventLoopGroup().next()
        url.coordinatedRead(self) { (url, error) in
            guard let url = url else { return }
            let io = NonBlockingFileIO(threadPool: .init(numberOfThreads: 3))
            
            _ = io.readEntireFile(url.path,
                              on: eventLoop)
                .map { data in
                    var bytes = data
                    let flac = Flac()
                    cover = flac.getFlacAlbum(bytes: &bytes)
            }
            
            self.load(title: title ?? "Unknow title",
                 artist: artist ?? "Unknown artist",
                 lyrics: nil,
                 album: album ?? "Unknown album",
                 cover: cover ?? UIImage(named: "LP")!,
                 bookmark: bookmark ?? (try? url.bookmarkData()) )
            
            
            // TODO: make it so MP3 can also be parsed
            
            
        }
    }
}
