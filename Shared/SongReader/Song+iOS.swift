#if canImport(UIKit)
import UIKit

extension Song {
    var coverImage: UIImage {
        if let cover = cover {
            return UIImage(data: cover) ?? UIImage(named: "LP")!
        }
        // TODO: Decouple this
        return UIImage(named: "LP")!
    }
}
#endif
