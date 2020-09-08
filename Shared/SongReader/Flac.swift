import NIOTransportServices
import NIO
import Foundation
#if os(iOS)
import UIKit
#endif

struct Flac {
    struct Head {
        let isLast: Bool
        let metaType: Int
        let bodyLength: Int
    }
    
    /// A function to read the header files for a Flac file
    /// - Parameter bytes: The bytes for the Metablock header
    /// - Throws: a `SongError` if it can't read the file
    /// - Returns: The first `Bool` is telling the consumer wether the reading block is the last or not. The second return `Int` is the type of which the metadata block is as defined by [Flac](https://xiph.org/flac/format.html#metadata_block_header).
    func readHead(bytes: inout ByteBuffer) throws -> (Head) {
        guard let rawValue = bytes.readInteger(endianness: .big, as: UInt8.self) else { throw SongError.coundtReadFile }
        guard let length = bytes.readBytes(length: 3)?.uint32 else { throw SongError.coundtReadFile }
        
        let valueMask: UInt8 = 0x7f
        let bitMask: UInt8 = 0x80
        
        let isLast = rawValue & bitMask != 0
        let metablockType = Int(rawValue & valueMask)
        
        return Head(isLast: isLast,
                    metaType: metablockType,
                    bodyLength: Int(length))
    }
}
