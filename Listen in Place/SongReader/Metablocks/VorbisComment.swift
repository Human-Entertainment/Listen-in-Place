import NIO

struct VorbisComment: MetaBlcok {
    var comments: [String: String]
    init(bytes: inout ByteBuffer) throws {
        comments = try VorbisComment.getVorbisComment(bytes: bytes)
        //comments = [:]
        
    }
    
    private static func getVorbisComment(bytes data: ByteBuffer) throws -> [String: String] {
        var bytes = data
        guard let vendorEnd = bytes.readInteger(endianness: .little, as: UInt32.self)
        else { throw VorbisError.lengthError }
        let vendor = bytes.readString(length: Int(vendorEnd))
        
        print(vendor)
        
        var comments: [String: String] = [:]
        guard let commentListCount = bytes.readInteger(endianness: .little, as: UInt32.self)
        else { throw VorbisError.lengthError }
        for _ in 0..<commentListCount {
            guard let commentLength = bytes.readInteger(endianness: .little, as: UInt32.self)
            else { throw VorbisError.lengthError }
            guard let commentString = bytes.readString(length: Int(commentLength))
                else { throw VorbisError.commentError }
            print(commentString)
            let comment = commentString.split(separator: "=")
            comments[comment[0].lowercased()] = String(comment[1])
        }
        return comments
    }
    
    private static func extract(comment: String) -> String {
        print(comment)
        return "Hello"
    }
}

enum VorbisError: Error {
    case lengthError
    case commentError
}
