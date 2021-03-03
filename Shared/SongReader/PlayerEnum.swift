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
    
    func getSong() -> Song {
        var lyrics: String? = nil
        var title = "Unknown Title"
        var artist = "Unknown Artist"
        var cover: Data? = nil
        var album: String? = nil
        var bookmark: Data? = nil
        
        switch self {
            case .AVPlayer(let player, let url):
                guard let asset = player.currentItem?.asset else { break }
                lyrics = asset.lyrics
                
                
                
                asset.commonMetadata.forEach { metadata in
                    guard let common = metadata.commonKey else {
                        print("Not common key")
                        return
                    }
                    
                    switch common{
                        case .commonKeyTitle:
                            title = metadata.value as? String ?? title
                        case .commonKeyArtist, .commonKeyAuthor:
                            artist = metadata.value as? String ?? artist
                        case .commonKeyAlbumName:
                            album =  metadata.value as? String ?? album
                        case .commonKeyArtwork:
                            cover = metadata.value as? Data
                        default: break
                    }
                }
                
                bookmark = try? url.bookmarkData()
                break
            default:
                break
        }
        let metadata = Song.Metadata(title: title , artist: artist)
        var song = Song()
        song.metadata = metadata
        song.cover = cover
        song.bookmark = bookmark
        return song
    }
}
