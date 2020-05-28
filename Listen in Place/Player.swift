import Foundation
import AVFoundation
import UIKit

typealias Byte = UInt8

extension Data {
    var bytes: [Byte] {
        var byteArray = [UInt8](repeating: 0, count: self.count)
        self.copyBytes(to: &byteArray, count: self.count)
        return byteArray
    }
}

extension Array where Element == Byte {
    var data: Data {
        Data(bytes: self, count: self.count)
    }
}

enum PlayerEnum {
    case none
    case AVPlayer(AVPlayer, URL)
    
    func getSong() -> Song {
        var lyrics: String? = nil
        var title = "Unknown Title"
        var artist = "Unknown Artist"
        var album: UIImage? = nil
        switch self {
        case .AVPlayer(let player, let url):
            guard let asset = player.currentItem?.asset else { break }
            lyrics = asset.lyrics
            
            if let meta = self.getFlacMeta(url: url) {
                meta.forEach { key, value in
                    switch key.lowercased() {
                    case "title":
                        title = value
                        break
                    case "artist":
                        artist = value
                        break
                    default:
                        print("\(key): \(key)")
                        break
                    }
                }
                
                if let cgCover = try? AVAssetImageGenerator(asset: asset).copyCGImage(at: CMTime(seconds: 0.0,
                                                                                                preferredTimescale: .max),
                                                                                     actualTime: nil)
                {
                    album = UIImage(cgImage: cgCover)
                }
            }
            
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
                case .commonKeyArtwork:
                    album = UIImage(data: metadata.value as? Data ?? Data.init())
                default: break
                }
            }
            
            
            break
        default:
            break
        }
        
        
        return .init(title: title, artist: artist, lyrics: lyrics, album: album)
    }
    
    private func getFlacMeta(url: URL) -> [String: String]? {
        var fileID: AudioFileID? = nil
        guard AudioFileOpenURL(url as CFURL,
                               .readPermission,
                               kAudioFileFLACType,
                               &fileID) == noErr else { return nil }

        var dict: CFDictionary? = nil
        var dataSize = UInt32(MemoryLayout<CFDictionary?>.size(ofValue: dict))

        guard let audioFile = fileID else { return nil }

        guard AudioFileGetProperty(audioFile,
                                   kAudioFilePropertyInfoDictionary,
                                   &dataSize,
                                   &dict) == noErr else { return nil }


        AudioFileClose(audioFile)

        guard let cfDict = dict else { return nil }

        return .init(_immutableCocoaDictionary: cfDict)
    }
    
    private func getFlacAlbum(url: URL) -> UIImage? {
        return nil
        
    }
}

struct Song: Hashable {
    let title: String
    let artist: String
    let lyrics: String?
    let album: UIImage
    init(title: String, artist: String, lyrics: String? = nil, album: UIImage? = nil) {
        self.title = title
        self.artist = artist
        self.lyrics = lyrics
        self.album = album ?? UIImage(named: "LP")!
    }
}

struct AV {
    private var player: AVPlayer
    private var url: URL
}

final class Player: ObservableObject {
    private var player: PlayerEnum
    private var _avPlayer: AVPlayer?
    @Published var progress: Float = 0.0
    @Published var isPlaying = false
    private var url: URL? = nil
    private var audioQueue = DispatchQueue.init(label: "audio")
    var nowPlaying: Song? {
        queue[0]
    }
    
    func seek(to: Float){
        switch song {
        case .AVPlayer(let player, _):
            
            let duration = player.currentItem?.duration.seconds ?? 0
            let percent = Double(to) * duration
            player.seek(to: .init(seconds: percent, preferredTimescale: CMTimeScale(10)))
        default:
            break
        }
    }
    
    var queue: [Song] = []
    
    var song: PlayerEnum {
        set(song) {
            player = song
            
            switch song {
            case .AVPlayer(_, let url):
                self.url = url
            default:
                break
            }
            let currentSong = song.getSong()
            queue.removeAll(keepingCapacity: false)
            queue.append(currentSong)
            play()
        }
        
        get {
            player
        }
    }
    
    init() {
        player = .none
    }
    
    func toggle() {
        if isPlaying {
            pause()
            isPlaying = false
        } else {
            play()
            isPlaying = true
        }
    }
    
    func play(_ song: URL) {
        
    }
    
    func play() {
        switch player {
        case .AVPlayer(let player, _):
            player.play()
            player.addPeriodicTimeObserver(forInterval: .init(seconds: 0.1, preferredTimescale: CMTimeScale(10)),
                                           queue: nil,
                                           using: { time in
                                            let seconds = time.seconds
                                            let duration = player.currentItem?.duration.seconds ?? 0
                                            let percent = seconds / duration
                                            self.progress = Float( percent )
            })
            
        default:
            break
        }
        isPlaying = true
    }
    
    
    
    func pause() {
        switch player {
        case .AVPlayer(let player, _):
            player.pause()
        default:
            break
        }
    }
}
