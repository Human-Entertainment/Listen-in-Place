import NIO

@dynamicMemberLookup
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
        guard let vendor = bytes.readString(length: Int(vendorEnd)) else { throw VorbisError.vendorIssue }
        
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
    
    subscript(dynamicMember member: String) -> String? {
        comments[member]
    }
    
    private static func extract(comment: String) -> String {
        print(comment)
        return "Hello"
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
