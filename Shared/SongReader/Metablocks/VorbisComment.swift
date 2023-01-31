import NIO

@dynamicMemberLookup
struct VorbisComment: MetaBlcok {
    var comments: [String: String]
    init(bytes: inout ByteBuffer) throws {
        comments = try VorbisComment.getVorbisComment(bytes: bytes)        
    }
    
    private static func getVorbisComment(bytes data: ByteBuffer) throws -> [String: String] {
        var bytes = data
        guard let vendorEnd = bytes.readInteger(endianness: .little, as: UInt32.self)
        else { throw VorbisError.lengthError }
        guard let _ = bytes.readString(length: Int(vendorEnd)) else { throw VorbisError.vendorIssue }
        
        var comments: [String: String] = [:]
        guard let commentListCount = bytes.readInteger(endianness: .little, as: UInt32.self)
        else { throw VorbisError.lengthError }
        for _ in 0..<commentListCount {
            guard let commentLength = bytes.readInteger(endianness: .little, as: UInt32.self)
            else { throw VorbisError.lengthError }
            guard let commentString = bytes.readString(length: Int(commentLength))
                else { throw VorbisError.commentError }
            let comment = commentString.split(separator: "=")
            comments[comment[0].lowercased()] = String(comment[1])
        }
        return comments
    }
    
    subscript(dynamicMember member: String) -> String? {
        comments[member]
    }
}

extension VorbisComment: CustomStringConvertible {
    var description: String {
        var string = ""
        comments.forEach { (key, value) in
            string += "\(key): \(value)\n"
        }
        return string
    }
}

enum VorbisError: Error {
    case lengthError
    case commentError
    case vendorIssue
}
