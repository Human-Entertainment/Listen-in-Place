import Foundation
import AVFoundation
import UIKit
import MediaPlayer
import CoreData

typealias Byte = UInt8

enum SongError: Error {
    case noBookmark
}

struct Song: Hashable {
    private(set) var title: String
    private(set) var artist: String
    private(set) var lyrics: String? = nil
    private(set) var cover: UIImage
    private(set) var album: String? = nil
    private(set) var bookmark: Data? = nil
    init(title: String, artist: String, lyrics: String? = nil, album: String? = nil, cover: UIImage? = nil, bookmark: Data? = nil) {
        self.title = title
        self.artist = artist
        self.lyrics = lyrics
        self.album = album
        self.cover = cover ?? UIImage(named: "LP")!
        self.bookmark = bookmark
    }
    
    init(bookmark data: Data?) throws {
        guard let bookmark = data else { throw SongError.noBookmark }
            
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
            )
        self.init(url: url, bookmark: bookmark)
    }
    
    init(url: URL, bookmark: Data? = nil) {
        // TODO: Fix this
        var album: String? = nil
        var artist: String? = nil
        var title: String? = nil
        
        if let meta = Song.getFlacMeta(url: url) {
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
            
        }
        cover = Song.getFlacAlbum(url: url) ?? UIImage(named: "LP")!
        self.title = title ?? "Unknow title"
        self.artist = artist ?? "Unknown artist"
        self.album = album ?? "Unknown album"
        self.bookmark = bookmark ?? (try? url.bookmarkData())
    }
    
    private static func getFlacMeta(url: URL) -> [String: String]? {
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
    
    private static func getFlacAlbum(url: URL) -> UIImage? {
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
            } else {
                print(picture.mimeType)
            }
        }
        
        return cover
        
    }
    
    private static func readBlock(byte: [Byte]) -> [MetaBlcok]  {
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

final class Player: ObservableObject {
    
    private var player: PlayerEnum
    private var _avPlayer: AVPlayer?
    @Published var progress: Float = 0.0
    @Published var isPlaying = false
    private var url: URL? = nil
    private var audioQueue = DispatchQueue.init(label: "audio")
    @Published var nowPlaying: Song? = nil
    
    // MARK: Access
    
    @Published var all = [Song]()
    
    func add(url: URL) {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }
        
        let newSong = Songs(context: context)
        newSong.bookmark = try? url.bookmarkData()
        
        try? context.save()
    }
    
    // MARK: Setup
    
    init() {
        player = .none
        // Setup mediacenter controls
        setupRemoteTransportControls()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avPlayerDidFinishPlaying(note:)),
                                               name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Songs")
            
            do {
                let result = try context.fetch(request)
                
                (result as! [NSManagedObject]).forEach { result in
                    guard let bookmark = result.value(forKey: "bookmark") as? Data else { return }
                    guard let song = try? Song(bookmark: bookmark) else { return }
                    self.all.append(song)
                }
            } catch {
                
            }
        }
        
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
    

    // MARK: controls
    func play(_ song: Song) throws {
        guard let bookmark = song.bookmark else { throw SongError.noBookmark }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        pause()
        player = .AVPlayer(.init(url: url), url)
        
        switch player {
            case .AVPlayer(_, let url):
                self.url = url
            default:
                break
        }
        let currentSong = player.getSong()
        nowPlaying = currentSong
        
        // TODO: Empty queue and add this song to queue
        
        play()
    }
    
    var token: Any?
    
    func play() {
        switch player {
        case .AVPlayer(let player, _):
            player.play()
            let interval = 1.0/240
            token = player.addPeriodicTimeObserver(forInterval: .init(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                                                   queue: nil,
                                                   using: {time in
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
    
    @objc func avPlayerDidFinishPlaying(note: NSNotification) {
        guard case let PlayerEnum.AVPlayer(player, _) = self.player else { return }
        if let token = token {
            player.removeTimeObserver(token)
        }
        
        // TODO: Remove first item in queue
        
        self.player = .none
        isPlaying = false
        
    }
    
    
    
    func pause() {
        switch player {
        case .AVPlayer(let player, _):
            player.pause()
            
        default:
            break
        }
    }
    
    func seek(to: Float){
        switch player {
            case .AVPlayer(let player, _):
                
                let duration = player.currentItem?.duration.seconds ?? 0
                let percent = Double(to) * duration
                player.seek(to: .init(seconds: percent, preferredTimescale: CMTimeScale(10)))
            default:
                break
        }
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
}
