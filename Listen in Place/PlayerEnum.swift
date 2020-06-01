import AVFoundation
import UIKit

enum PlayerEnum {
    case none
    case AVPlayer(AVPlayer, URL)
    
    func getSong() -> Song {
        var lyrics: String? = nil
        var title = "Unknown Title"
        var artist = "Unknown Artist"
        var cover: UIImage? = nil
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
                            album = metadata.value as? String ?? album
                        case .commonKeyArtwork:
                            cover = UIImage(data: metadata.value as? Data ?? Data.init())
                        default: break
                    }
                }
                
                bookmark = try? url.bookmarkData()
                break
            default:
                break
        }
        
        let song = Song()
            song.load(title: title, artist: artist, lyrics: lyrics, album: album, cover: cover, bookmark: bookmark)
        return song
    }
}
