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
                
                bookmark = try? url.bookmarkData()
                break
            default:
                break
        }
        
        
        return .init(title: title, artist: artist, lyrics: lyrics, album: album, cover: cover, bookmark: bookmark)
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
            } else {
                print(picture.mimeType)
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
