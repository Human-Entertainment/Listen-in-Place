import GRDB
import Combine
import SwiftUI

class AlbumObserving: ObservableObject
{
    @Published
    var albums: [Song]
    var cancellabled: Set<AnyCancellable>
    
    init(
        on dbQueue: DatabaseQueue
    ) {
        albums = .init()
        cancellabled = .init()
        ValueObservation.tracking { database in
                try Song.fetchAll(database)
            }.publisher(in: dbQueue)
            .sink(
                receiveCompletion: {error in
                    
                },
                receiveValue: { [weak self] model in
                    self?.albums.append(contentsOf: model)
            }).store(in: &cancellabled)
        
        DispatchQueue(label: "Hello").async { [weak self] in
            sleep(5)
            guard let `self` = self else { print("Self wasn't retained"); return }
            print(self.albums)
        }
    }
}
