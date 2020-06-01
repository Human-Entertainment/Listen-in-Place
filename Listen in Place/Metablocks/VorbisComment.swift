struct VorbisComment: MetaBlcok {
    init(bytes: ArraySlice<Byte>) {
        _ = VorbisComment.getVorbisComment(bytes: bytes)
        
        
    }
    
    private static func getVorbisComment(bytes: ArraySlice<Byte>) -> [String] {
        let start = bytes.startIndex
        
        let vendorStart = start + 4
        let vendorEnd = Int( bytes[start..+<1].data.bytes.uint32 + UInt32(start) )
        let vendor = String(bytes: bytes[vendorStart..<vendorEnd], encoding: .utf8)
        let commentListStart = vendorEnd + 4
        let commentListCount = bytes[vendorEnd..+<1].uint32
        
        var comments = [String]()
        var currentComment = 0
        var commentStart = commentListStart
        while currentComment != commentListCount {
            let commentLengthEnd = commentStart + 4
            let commentStringStart = commentLengthEnd + 4
            let commentLength = bytes[commentLengthEnd..+<1].int + commentLengthEnd
            let comment = String(bytes: bytes[commentStringStart..<commentLength], encoding: .utf8)!
            comments.append(extract(comment: comment))
            commentStart = commentLength
            currentComment+=1
        }
        return comments
    }
    
    private static func extract(comment: String) -> String {
        print(comment)
        return "Hello"
    }
}

