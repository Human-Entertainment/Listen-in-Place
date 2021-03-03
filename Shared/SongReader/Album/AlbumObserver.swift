import Combine
import GRDB

class AlbumObserver: ObservableObject
{
    private(set) var album = Set<Album>()
    // Initializer hack so we can use it in the sink
    private var cancelable = AnyCancellable.init{}
    
    init(dbPool: DatabasePool) {
        self.cancelable = ValueObservation
            .tracking {db in
                try Album.fetchAll(db)
            }
            .publisher(in: dbPool)
            .sink(
                receiveCompletion: {err in
                    print(err)
                },
                receiveValue: { album in
                    album.forEach { [weak self] in self?.album.insert($0) }
                }
            )
            
    }

    deinit {
        cancelable.cancel()
    }
}
