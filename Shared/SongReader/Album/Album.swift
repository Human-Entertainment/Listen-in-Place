import GRDB
import Foundation

struct Album: Codable
{
    var id: Int64? = nil
    var name: String
    var cover: Data? = nil

    init(name: String) { self.name = name }

    init(row: Row)
    {
        self.id = row["id"]
        self.name = row["name"]
        self.cover = row["cover"]
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(cover)
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

extension Album: Identifiable {}
extension Album: Hashable
{
    public static func ==(lhs: Album, rhs: Album) -> Bool
    {
        lhs.cover == rhs.cover &&
        lhs.name == rhs.name &&
        lhs.id == rhs.id
    }
}

extension Album: FetchableRecord {}
extension Album: PersistableRecord {}