import NIOTransportServices
import NIO
import Foundation
import UIKit

struct Flac {
    
    func getFlacAlbum(bytes: inout ByteBuffer) -> UIImage? {
        let bufferView = ByteBufferView(bytes)
        var fileBytes = ByteBuffer(bufferView)
        
        guard fileBytes.readString(length: 4) == "fLaC" else
        {
            print("Not a flac")
            return nil
        }
        print("Isa flac")
        let blocks = readBlock(bytes: &fileBytes)
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
    
    func readBlock(bytes: inout ByteBuffer) -> [MetaBlcok]  {
        let valueMask: UInt8 = 0x7f
        let bitMask: UInt8 = 0x80
        var last = false
        var block = [MetaBlcok]()
        while !last {
            guard let rawValue = bytes.readInteger(endianness: .big, as: UInt8.self) else { return block }
            last = rawValue & bitMask != 0
            let length = bytes.readInteger(endianness: .big, as: UInt32.self)
            print("Reading block of \(length) bytes")
            switch rawValue & valueMask {
                case 0:
                    guard let streamInfo = try? Streaminfo(bytes: &bytes) else { return block }
                    block.append(streamInfo)
                    break
                case 4:
                    guard let comment = try? VorbisComment(bytes: &bytes) else { return block }
                    block.append(comment)
                    break
                case 6:
                    guard let picture = try? Picture(bytes: &bytes) else { return block }
                    block.append(picture)
                    break
                default: break
                
            }
        }
        return block
        
    }
}
