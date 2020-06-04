import NIO

struct VorbisComment: MetaBlcok {
    var comments: [String: String]
    init(bytes: inout ByteBuffer) throws {
        //comments = try? VorbisComment.getVorbisComment(bytes: bytes)
        comments = [:]
        
    }
    
    private static func getVorbisComment(bytes data: ByteBuffer) throws -> [String: String] {
        /*
        var bytes = data
        guard let vendorEnd = (bytes.readBytes(length: 4)?.reversed().reduce(0 as UInt32) { ($0 << 8) | UInt32($1) })
        else { throw VorbisError.lengthError }
        let vendor = bytes.readString(length: Int(vendorEnd))
        /*
        let commentListStart = vendorEnd + 4
        let commentListCount = bytes[vendorEnd..+<1].uint32
        
        var comments = [String]()
        var commentStart = commentListStart
        for _ in 0..<commentListCount {
            let commentLengthEnd = commentStart + 4
            let commentStringStart = commentLengthEnd + 4
            let commentLength = bytes[commentLengthEnd..+<1].int + commentLengthEnd
            let comment = String(bytes: bytes[commentStringStart..<commentLength], encoding: .utf8)!
            comments.append(extract(comment: comment))
            commentStart = commentLength
        }
        return comments
         
         */return*/ return [:]
    }
    
    private static func extract(comment: String) -> String {
        print(comment)
        return "Hello"
    }
}

enum VorbisError: Error {
    case lengthError
}
