#if os(iOS)
import UIKit
#endif
import NIO

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
    let image: Data?
    
    init(bytes: inout ByteBuffer) throws {
        //guard let pictureType =  else { throw PictureError.pictureTypeError }
        
        switch bytes.readInteger(endianness: .big, as: UInt32.self) {
            case 3:
                self.pictureType = .CoverFront
            case nil:
                throw PictureError.pictureTypeError
            default:
                self.pictureType = .other
                print(pictureType)
                break
        }
        
        guard let mimeLength = bytes.readInteger(endianness: .big, as: UInt32.self) else { throw PictureError.mimeError }
        guard let mimeType = bytes.readString(length: Int(mimeLength)) else {
            throw PictureError.mimeError
        }
        self.mimeType = mimeType
        
        guard let descriptionLength = bytes.readInteger(endianness: .big, as: UInt32.self) else {
            throw PictureError.descriptionError
        }
        guard let description = bytes.readString(length: Int(descriptionLength)) else {
            throw PictureError.descriptionError
        }
        self.description = description
        
        guard let width = bytes.readInteger(endianness: .big, as: UInt32.self) else {
            throw PictureError.sizeError
        }
        self.width = Int(width)
        
        guard let height = bytes.readInteger(endianness: .big, as: UInt32.self) else {
            throw PictureError.sizeError
        }
        self.height = Int(height)
        
        guard let colorDepth = bytes.readInteger(endianness: .big, as: UInt32.self) else {
            throw PictureError.sizeError
        }
        self.colorDepth = Int(colorDepth)
        
        guard let colorCount = bytes.readInteger(endianness: .big, as: UInt32.self) else {
            throw PictureError.sizeError
        }
        self.colorCount = Int(colorCount)
        
        guard let imageLength = bytes.readInteger(endianness: .big, as: UInt32.self) else {
            throw PictureError.dataError
        }
        guard let data = bytes.readBytes(length: Int(imageLength))?.data else {
            throw PictureError.dataError
        }
        
        self.image = data
    }
    
    init(bytes: ArraySlice<Byte>) {
        let start = bytes.startIndex
        let mimeLengthStart = start + 4
        let mimeStart = mimeLengthStart + 4
        let pictureType = bytes[start..<mimeLengthStart].int
        switch pictureType {
            case 3:
                self.pictureType = .CoverFront
            default:
                self.pictureType = .other
                print(pictureType)
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
        image = imageData
    }
}

enum PictureError: Error {
    case pictureTypeError
    case mimeError
    case descriptionError
    case sizeError
    case dataError
}
