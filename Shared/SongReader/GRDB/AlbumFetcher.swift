import GRDB
import Combine
import SwiftUI

class AlbumObserving: ObservableObject
{
    @Published
    var albums: [Album]
    var cancellable: Set<AnyCancellable>
    
    init(
        on dbWriter: DatabaseWriter
    ) {
        albums = .init()
        // Set so we can mutate the albums any time
        cancellable = .init()
        ValueObservation.tracking(Album.all().fetchAll)
            .publisher(in: dbWriter)
            .sink(
                receiveCompletion: {error in
                    
                },
                receiveValue: append
            ).store(in: &cancellable)
    }

    func append(album: [Album])
    {
        self.albums.append(contentsOf: album)
    }
}
