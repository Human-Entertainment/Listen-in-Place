import Foundation
import AVFoundation
import MediaPlayer
import CoreData
import Combine
import NIO
import NIOTransportServices
import OrderedCollections
import Observation

typealias Byte = UInt8

@Observable
final class Player: ObservableObject {
    private var player: AVPlayer? = nil
    
    var progress: Float = 0.0
    var isPlaying = false
    private var url: URL? = nil
    var nowPlaying: Song? = nil
    
    var cancellable = [AnyCancellable]()
    
    var timerObserver: Any? = nil
    
    // MARK: - Setup
    init() {
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set the audio session category, mode, and options.
            try audioSession.setCategory(.playback, mode: .default, options: [])
        } catch {
            print("Failed to set audio session category.")
        }
        
        player = nil
        // Setup mediacenter controls
        setupRemoteTransportControls()
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink(receiveValue: avPlayerDidFinishPlaying)
            .store(in: &cancellable)
        
        withMutation(keyPath: \.isPlaying) {
            let infoCenter = MPNowPlayingInfoCenter.default()
            infoCenter.playbackState = self.isPlaying ? .playing : .paused
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
        
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] remoteEvent in
            guard let event = remoteEvent as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
    
            //let duration = player.currentItem?.duration.seconds ?? 0
            let seek = event.positionTime
            guard let player = player else { return .noActionableNowPlayingItem }
            player.seek(to: CMTime(seconds: seek, preferredTimescale: CMTimeScale(1000)))
            return .success
            
            
        }
        
        commandCenter.nextTrackCommand.addTarget { [unowned self] remoteEvent in
            guard self.nextSong() != nil else { return .noSuchContent }
            self.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { _ in
            return .commandFailed
        }
        
        /*
        commandCenter.bookmarkCommand.addTarget { [unowned self] event in
            .commandFailed
        }
*/
    }
    
    func setupNowPlaying(song: Song, elapsed: Double, total: Double) {
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        
        nowPlayingInfo[MPMediaItemPropertyArtwork] =
            MPMediaItemArtwork(boundsSize: song.coverImage.size) { size in
                return song.coverImage
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = total
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1
        
        // Set the metadata
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.nowPlayingInfo = nowPlayingInfo
        
    }
    

    // MARK: - Queue
    @ObservationTracked
    private(set) var sharedQueue = [Song]()
    
    func addToQueue(_ song: Song) {
        sharedQueue.append(song)
    }
    
    func nextSong() -> Song? {
        if sharedQueue.count > 0 {
            return sharedQueue.removeFirst()
        } else {
            return nil
        }
    }

    // MARK: - Controls
    func play(_ song: Song) throws {
        guard let bookmark = song.bookmark else { throw SongError.noBookmark }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        guard url.startAccessingSecurityScopedResource() else {
            return
        }
        
        pause()
        player = .init(url: url)
        
        self.url?.stopAccessingSecurityScopedResource()
        self.url = url
        nowPlaying = song
        
        // TODO: Empty queue and add this song to queue
        
        play()
    }
    
    deinit {
        url?.stopAccessingSecurityScopedResource()
    }
    
    func addPeriodicTimeObserver()
    {
            
        let interval = 1.0 / 240
        timerObserver = player?.addPeriodicTimeObserver(
                forInterval: .init(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                queue: nil,
                using: {time in
                    let seconds = time.seconds
                    let duration = self.player?.currentItem?.duration.seconds ?? 0
                    let percent = seconds / duration
                    self.progress = Float( percent )
                    self.setupNowPlaying(song: self.nowPlaying!, elapsed: seconds, total: duration)
                })
    }
    
    func removePeriodicTimeObserver()
    {
        guard let token = timerObserver else {
            return
        }
        player?.removeTimeObserver(token)
        
        timerObserver = nil
    }
    
    func play() {
        guard let player = player else {
            return
        }
        player.publisher(for: \.timeControlStatus)
            .sink { controlStatus in
                switch controlStatus {
                    case .paused: self.isPlaying = false
                    case .playing: self.isPlaying = true
                    case .waitingToPlayAtSpecifiedRate:
                        self.isPlaying = false
                    @unknown default:
                        self.isPlaying = false
                }
            }.store(in: &cancellable)
        player.play()
        
        self.addPeriodicTimeObserver()
        
        NotificationCenter
            .default
            .publisher(for: AVAudioSession.interruptionNotification)
            .sink(receiveValue: handleInterruption)
            .store(in: &cancellable)
            
        
        isPlaying = true
           
    }
    
    func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }
        
        // Switch over the interruption type.
        switch type {
            
            case .began:
            // An interruption began. Update the UI as needed.
                self.isPlaying = false
            case .ended:
                // An interruption ended. Resume playback, if appropriate.
                
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption ended. Playback should resume.
                    self.play()
                } else {
                    // Interruption ended. Playback should not resume.
            }
            
            default: ()
        }
    }
    
    func avPlayerDidFinishPlaying(note: Notification) {
        self.removePeriodicTimeObserver()
        
        playNext()
    }
    
    func playNext() {
        pause()
        self.player = .none
        isPlaying = false
        if let nextSong = nextSong() {
            try? play(nextSong)
        }
    }
    
    func pause() {
        isPlaying = false
        player?.pause()
    }
    
    func seek(to: Float){
                
        let duration = player?.currentItem?.duration.seconds ?? 0
        let percent = Double(to) * duration
        player?.seek(to: .init(seconds: percent, preferredTimescale: CMTimeScale(10)))
           
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
