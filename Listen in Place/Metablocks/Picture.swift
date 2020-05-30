import UIKit

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
        image = UIImage(data: imageData)
    }
}
