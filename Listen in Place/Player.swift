import Foundation
import AVFoundation
import UIKit
import MediaPlayer

typealias Byte = UInt8

protocol MetaBlcok {
    init(bytes: ArraySlice<Byte>)
}

struct Streaminfo: MetaBlcok {
    let bytes: ArraySlice<Byte>
    init(bytes: ArraySlice<Byte>) {
        self.bytes = bytes
    }
}

enum PictureType {
    case CoverFront
    case other
}

struct Picture: MetaBlcok {
    let pictureType: PictureType
    let mimeType: String
    let description: String
    let width: Int
    let height: Int
    let colorDepth: Int
    let colorCount: Int
    let image: UIImage?
    
    init(bytes: ArraySlice<Byte>) {
        let start = bytes.startIndex
        let mimeLengthStart = start + 4
        let mimeStart = mimeLengthStart + 4
        switch bytes[start..<start + mimeStart].int {
            case 3:
                pictureType = .CoverFront
            default:
                pictureType = .other
                break
        }
        
        /// End position of the MimeType string
        let mimeLength = bytes[mimeLengthStart..<mimeStart].int + mimeStart
        
        mimeType = String(bytes: bytes[mimeStart..<mimeLength], encoding: .ascii) ?? ""
        
        let descriptionStart = mimeLength + 4
        /// The end position of the description
        let descriptionLength = bytes[mimeLength..<descriptionStart].int + descriptionStart
        
        description = String(bytes: bytes[descriptionStart..<descriptionLength], encoding: .ascii) ?? ""
        
        let widthEnd = descriptionLength + 4
        width = bytes[descriptionLength..<widthEnd].int
        
        let heightEnd = widthEnd + 4
        height = bytes[widthEnd..<heightEnd].int
        
        let colorDepthEnd = heightEnd + 4
        colorDepth = bytes[heightEnd..<colorDepthEnd].int
        
        let colorCountEnd = colorDepthEnd + 4
        colorCount = bytes[colorDepthEnd..<colorCountEnd].int
        
        let pictureLengthEnd = colorCountEnd + 4
        let pictureLength = bytes[colorCountEnd..<pictureLengthEnd].int + pictureLengthEnd
        
        let imageData = bytes[pictureLengthEnd..<pictureLength].data
        image = UIImage(data: imageData)
    }
}

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

protocol ArrayAble: Sequence {
    var count: Int { get }
}

extension ArrayAble where Element == Byte {
    var data: Data {
        Data(self)
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

extension Array: ArrayAble {}
extension ArraySlice: ArrayAble {}

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
        let blocks = readBlock(byte: Array(fileBytes[4..<fileBytes.count]))
        let pictures = blocks.compactMap { $0 as? Picture }
        
        print(pictures.count)
        
        var cover: UIImage? = nil
        
        pictures.forEach { picture in
            if picture.pictureType == .CoverFront {
                cover = picture.image
            }
        }
        
        return cover
        
    }
    
    private func readBlock(byte: [Byte]) -> [MetaBlcok]  {
        var i = 0
        let valueMask: UInt8 = 0x7f
        let bitMask: UInt8 = 0x80
        var last = false
        var block = [MetaBlcok]()
        while !last {
            let rawValue = byte[i]
            last = rawValue & bitMask != 0
            let length = Array(byte[i+1..<i+4]).int
            i += 4
            switch rawValue & valueMask {
                case 0:
                    block.append(Streaminfo(bytes: byte[i..<i+length] ))
                    break
                case 6:
                    block.append(Picture(bytes: byte[i..<i+length]))
                    break
                default: break
                    
            }
            i += length
        }
        return block
        
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
