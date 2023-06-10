import NIO
import NIOTransportServices
import Foundation
import Combine
import System
import SwiftData

enum SongError: Error {
    case noBookmark
    case coundtReadFile
}

@Model
final class Song {
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

    func loadVorbis(comment vorbis: VorbisComment) {
        self.title = vorbis.title ?? self.title
        self.artist = vorbis.artist ?? self.artist
        self.tracknumber = vorbis.tracknumber
        
        self.album = vorbis.album
    }
    
    func set(cover data: Data?) {
        cover = data
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

extension Song {
    
    static func load(url: URL, bookmark: Data, on threadPool: NIOThreadPool) async throws -> Song {
        let url = try await url.coordinatedRead(coordinator: NSFileCoordinator())
                
        let song = Song(title: "unknown", artist: "unknown", bookmark: bookmark)
        do {
            for try await (buffer, metaType) in try await NonBlockingFileIO(threadPool: threadPool)
                .metablockReader(path: url.path(percentEncoded: false), on: NIOTSEventLoopGroup().next())
            {
                switch metaType {
                    case 0:
                        print("Streaminfo block")
                        continue
                    case 1:
                        print("Padding block")
                        continue
                    case 2:
                        print("Application block")
                        continue
                    case 3:
                        print("Seekable block")
                        continue
                    case 4:
                        print("Vorbis comment block")
                        guard let vorbis = try? VorbisComment(bytes: buffer) else { continue }
                        song.loadVorbis(comment: vorbis)

                    case 5:
                        print("Cuesheet")
                        continue
                    case 6:
                        print("Image")
                        do {
                            let picture = try Picture(bytes: buffer)
                            
                            if picture.pictureType == .CoverFront {
                                let cover = picture.image
                                song.set(cover: cover)
                            } else {
                                print(picture.mimeType)
                                continue
                            }
                        } catch {
                            print("Image loading issue \(error)")
                            continue
                        }
                    default:
                        assertionFailure("Heck?")
                        break
                }
            }
        } catch {
            print(error)
            if error as? NonBlockingFileIOReadError == NonBlockingFileIOReadError.notFlac {
                // Fallback for when the song metadata isn't supported
                let avEnum = PlayerEnum.AVPlayer(.init(url: url), url)
                return try await avEnum.getSong()
            } else {
                throw error
            }
        }
            
        return song
       
    }

}
