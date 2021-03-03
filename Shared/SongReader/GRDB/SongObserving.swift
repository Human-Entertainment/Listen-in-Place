//
// Created by Bastian Inuk Christensen on 03/03/2021.
// Copyright (c) 2021 Bastian Inuk Christensen. All rights reserved.
//

import Combine
import GRDB

class SongObserving: ObservableObject
{
    var songs: [Song]
    var cancellable: Set<AnyCancellable>

    init(
            on dbWriter: DatabaseWriter,
            album parent: Album
    )
    {
        songs = .init()
        cancellables = .init()

        ValueObservation
        .tracking (
            Song
            .filter(Column("albumID") == parent.id)
            .fetchAll
        ).publisher(in: dbWriter)
        sink(
                receiveCompletion: {error in

                },
                receiveValue: append
        ).store(in: &cancellable)
    }

    func append(songs: [Song])
    {
        self.songs.append(contentsOf: songs)
    }

}
