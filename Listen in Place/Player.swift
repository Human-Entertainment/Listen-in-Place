import Foundation
import AVFoundation
import UIKit
import MediaPlayer

typealias Byte = UInt8

enum Bit: UInt8, CustomStringConvertible {
    case zero, one

    var description: String {
        switch self {
        case .one:
            return "1"
        case .zero:
            return "0"
        }
    }
}
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
    
    var bits: [Bit] {
        self.flatMap { byte in
            byte.bits
        }
    }
    
    var int: Int {
        var compound = 0
        let ints = self.map { Int($0) }
        for i in 0..<self.count {
            let reverseIndex = self.count - i - 1
            compound += ints[i] << (reverseIndex * 8)
        }
        return compound
    }
}

extension FixedWidthInteger {
    var bits: [Bit] {
        var bitArray = self
        var bits = [Bit](repeating: .zero, count: self.bitWidth)
        for i in 0..<self.bitWidth {
            let currentBit = bitArray & 0x01
            if currentBit != 0 {
                bits[i] = .one
            }

            bitArray >>= 1
        }

        return bits
    }
}

enum PlayerEnum {
    case none
    case AVPlayer(AVPlayer, URL)
    
    func getSong() -> Song {
        var lyrics: String? = nil
        var title = "Unknown Title"
        var artist = "Unknown Artist"
        var cover: UIImage? = nil
        var album: String? = nil
        
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
                    case "album":
                        album = value
                    default:
                        print("\(key): \(value)")
                        break
                    }
                }
                cover = getFlacAlbum(url: url)
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
                    cover = UIImage(data: metadata.value as? Data ?? Data.init())
                default: break
                }
            }
            
            
            break
        default:
            break
        }
        
        
        return .init(title: title, artist: artist, lyrics: lyrics, album: album, cover: cover)
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
        guard let file = try? Data(contentsOf: url) else { return nil }
        let fileBytes = file.bytes
        
        guard String(bytes: fileBytes[0...3], encoding: .ascii) == "fLaC" else
        {
            print("Not a flac")
           return nil
        }
        print("Isa flac")
        print(readBlockHeader(byte: Array(fileBytes[4...8])))
        
        
        
        return nil
        
    }
    
    private func readBlockHeader(byte: [Byte]) -> MetaHeader {
        let (isLast, type) = isLastAndType(int: byte[0])
        return MetaHeader(last: isLast,
                   type: type,
                   length: Array(byte[1..<4]).int )
    }
    
    func isLastAndType(int: UInt8) -> (Bool, MetaType) {
        let isLast = int >= 1 << 7
        let type = MetaType(rawValue: int)
        return (isLast, type)
    }
    
    struct MetaHeader {
        var last: Bool
        var type: MetaType
        var length: Int
    }
    
    enum MetaType {
        case STREAMINGINFO
        
        case other
        init(rawValue: UInt8) {
            switch rawValue {
            case 0, 1 << 7 + 0:
                self = .STREAMINGINFO
            default:
                self = .other
            }
        }
    }
}

struct Song: Hashable {
    let title: String
    let artist: String
    let lyrics: String?
    let cover: UIImage
    let album: String?
    init(title: String, artist: String, lyrics: String? = nil, album: String? = nil, cover: UIImage? = nil) {
        self.title = title
        self.artist = artist
        self.lyrics = lyrics
        self.album = album
        self.cover = cover ?? UIImage(named: "LP")!
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
        setupRemoteTransportControls()
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
                                            self.setupNowPlaying(song: self.nowPlaying!, elapsed: seconds, total: duration)
            })
            
        default:
            break
        }
        isPlaying = true
    }
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()

        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.play()
            return .success
        }

        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.pause()
            return .success
        }
    }
    
    func setupNowPlaying(song: Song, elapsed: Double, total: Double) {
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title

        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        
        nowPlayingInfo[MPMediaItemPropertyArtwork] =
            MPMediaItemArtwork(boundsSize: song.cover.size) { size in
                return song.cover
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = total
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1

        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
