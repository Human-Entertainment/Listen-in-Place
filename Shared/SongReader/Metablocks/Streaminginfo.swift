import NIO

struct Streaminfo {
    let bytes: ByteBuffer
    
    init(bytes: ByteBuffer) throws {
        self.bytes = bytes
    }
}
