import SwiftData
import Foundation

@Model
class Songs {
    @Attribute(.unique)
    var bookmark: Data
    
    init(bookmark: Data) {
        self.bookmark = bookmark
    }
}
