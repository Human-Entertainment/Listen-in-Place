struct Streaminfo: MetaBlcok {
    let bytes: ArraySlice<Byte>
    init(bytes: ArraySlice<Byte>) {
        self.bytes = bytes
    }
}
