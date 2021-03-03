import GRDB
import Foundation

enum SongError: Error {
    case noBookmark
    case coundtReadFile
}

struct Song: Codable
{
    struct Metadata: Codable, PersistableRecord, FetchableRecord
    {
        var title: String
        var artist: String
        var tracknumber: String? = nil
    }
    var id: Int64?
    var cover: Data? = nil
    var albumID: Int64?
    var bookmark: Data? = nil
    var metadata: Metadata? = nil
}

extension Song: Identifiable {}
extension Song: Hashable {
    public static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.metadata == rhs.metadata &&
        lhs.albumID == rhs.albumID &&
        lhs.cover == rhs.cover
    }
}

extension Song: FetchableRecord {}
extension Song: PersistableRecord {}

extension Song.Metadata: Hashable {
    static func == (lhs: Song.Metadata, rhs: Song.Metadata) -> Bool {
        lhs.artist == rhs.artist &&
        lhs.title == lhs.title &&
        lhs.tracknumber == rhs.tracknumber
    }
}

