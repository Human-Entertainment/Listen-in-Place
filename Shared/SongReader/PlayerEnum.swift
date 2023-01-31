import AVFoundation
import UIKit

enum PlayerEnum {
    case none
    case AVPlayer(AVPlayer, URL)
    
    func addPeriodicTimeObserver(playerObserver: Player) -> Any
    {
        guard case let .AVPlayer(player, _) = self else { return Void() }
        
        let interval = 1.0 / 240
        return (player.addPeriodicTimeObserver(
            forInterval: .init(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: nil,
            using: {time in
                let seconds = time.seconds
                let duration = player.currentItem?.duration.seconds ?? 0
                let percent = seconds / duration
                playerObserver.progress = Float( percent )
                playerObserver.setupNowPlaying(song: playerObserver.nowPlaying!, elapsed: seconds, total: duration)
            }), player)
    }
    
    func removePeriodicTimeObserver(token timeObserver: Any?)
    {
        guard let (token, player) = timeObserver as? (Any, AVPlayer)
        else { return }
        
        player.removeTimeObserver(token)
    }
    
    func getSong() async throws -> Song {
        var lyrics: String? = nil
        var title = "Unknown Title"
        var artist = "Unknown Artist"
        var cover: Data? = nil
        var album: String? = nil
        var bookmark: Data? = nil
        
        if case let .AVPlayer(player, url) = self {
            guard let asset = player.currentItem?.asset else {
                throw Error.wrongSong
            }
            
            lyrics = try? await asset.load(.lyrics)
            
            for metadata in try await asset.load(.commonMetadata) {
                guard let common = metadata.commonKey else {
                    print("Not common key")
                    continue
                }
                
                switch common{
                    case .commonKeyTitle:
                    title = try await metadata.load(.value) as? String ?? title
                    case .commonKeyArtist, .commonKeyAuthor:
                        artist = try await metadata.load(.value) as? String ?? artist
                    case .commonKeyAlbumName:
                        album = try await metadata.load(.value) as? String ?? album
                    case .commonKeyArtwork:
                        cover = try? await metadata.load(.value) as? Data
                    default: break
                }
            }
            
            bookmark = try? url.bookmarkData()
            
        }
        
        let song = Song(title: title,
                        artist: artist,
                        lyrics: lyrics,
                        album: album,
                        cover: cover,
                        bookmark: bookmark)
        return song
    }
    
    enum Error : Swift.Error {
        case wrongSong
    }
}
