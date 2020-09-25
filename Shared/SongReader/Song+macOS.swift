#if canImport(AppKit)
import AppKit

extension Song {
    var coverImage: NSImage {
        if let cover = cover {
            return NSImage(data: cover) ?? NSImage(named: "LP")!
        }
        // TODO: Decouple this
        return NSImage(named: "LP")!
    }
}
#endif
