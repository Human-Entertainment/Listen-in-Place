import NIO

struct Streaminfo: MetaBlcok {
    let bytes: ByteBuffer
    
    init(bytes: inout ByteBuffer) throws {
        self.bytes = bytes
    }
}
