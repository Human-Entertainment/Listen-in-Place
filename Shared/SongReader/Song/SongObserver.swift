import Combine
import GRDB

class SongObserver: ObservableObject
{
    private(set) var songs = Set<Song>()
    // Initializer hack so we can use it in the sink
    private var cancelable = AnyCancellable.init{}
    
    init(dbPool: DatabasePool, album: Album) {
        self.cancelable = ValueObservation
            .tracking {db in
                try Song
                    .filter(Column("name") == album.id)
                    .order(Column("tracknumber"))
                    .fetchAll(db)
            }
            .publisher(in: dbPool)
            .sink(
                receiveCompletion: {err in
                    print(err)
                },
                receiveValue: { songs in
                    songs.forEach { [weak self] in self?.songs.insert($0) }
                }
            )
            
    }
}
