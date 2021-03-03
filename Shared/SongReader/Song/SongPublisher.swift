import NIO
import NIOTransportServices
import Foundation
import GRDB
import Combine

struct SongPublisher {
    private let threadPool: NIOThreadPool

    private let eventLoop: EventLoop

    private let db: DatabaseWriter

    init(threadPool: NIOThreadPool,
         db: DatabaseWriter = AppDatabase.shared.dbWriter)
    {
        self.threadPool = threadPool
        self.eventLoop = NIOTSEventLoopGroup().next()
        self.db = db
    }

    func load(url: URL, bookmark: Data) throws -> Future<Song, SongError> {
        Future<Song, SongError> { promise in

            let coordinator = url.coordinatedRead(coordinator: NSFileCoordinator(),
                    on: eventLoop)
            coordinator.whenSuccess { url in

                self.threadPool.start()
                self.asyncLoad(
                        url: url,
                        threadPool: self.threadPool
                ).whenComplete { result in
                    switch (result) {
                    case let .failure(error):
                        print(error)
                        promise(.failure(.coundtReadFile))
                        break
                    case let .success(song):
                        var newSong = song
                        newSong.bookmark = bookmark
                        try? self.db.write {db in
                            try newSong.save(db)
                            print("Write song \(newSong.metadata?.title ?? "Unknown Track" ) to disk")
                        }
                        promise(.success(newSong))
                        break
                    }

                }
            }
            coordinator.whenFailure { error in
                promise(.failure(.coundtReadFile))
            }
        }

        // TODO: make it so MP3 can also be parsed
    }

    private func asyncLoad(
            url: URL,
            threadPool: NIOThreadPool) -> EventLoopFuture<Song> {

        NonBlockingFileIO(threadPool: threadPool)
                .metablockReader(
                        path: url.path,
                        on: eventLoop
                ) { data, flac, type, inSong  in
                    var song = inSong
                    var bytes = data
                    switch type {
                    case 0:
                        print("Streaminfro block")
                    case 1:
                        print("Padding block")
                    case 2:
                        print("Application block")
                    case 3:
                        print("Seekable block")
                    case 4:
                        print("Vorbis comment block")
                        guard let vorbis = try? VorbisComment(bytes: &bytes) else { return song }
                        print(vorbis)
                        guard let albumName = vorbis.album else {
                            // TODO: Better fallback for when there is no  album name
                            fatalError("No album name")
                        }

                        try? self.db.write { db in
                            var album = try Album
                                .filter(Column("name") == albumName)
                                .fetchOne(db)
                            if album == nil {
                                album = Album(name: albumName)
                                try album!.save(db)
                                print("Write album \(album!.name) to disk")
                            } else {
                                print("Found album in database")
                            }

                                song.albumID = album?.id
                            let metadata = Song.Metadata(
                                    title: vorbis.title ?? "Unknown Track" ,
                                    artist: vorbis.artist ?? "Unknown Artist",
                                    tracknumber: vorbis.tracknumber
                            )
                            song.metadata = metadata

                            try? db.commit()
                        }
                    case 5:
                        print("Cuesheet")
                    case 6:
                        print("Image")
                        do {
                            let picture = try Picture(bytes: &bytes)

                            if picture.pictureType == .CoverFront {
                                let cover = picture.image
                                print(cover as Any)
                                song.cover = cover
                            } else {
                                print(picture.mimeType)
                            }
                        } catch {
                            print("Image loading issue \(error)")
                        }
                    default:
                        assertionFailure("Heck?")
                    }
                    return song
                }.flatMapErrorThrowing { error in
            print(error)
            if error as? NonBlockingFileIOReadError == NonBlockingFileIOReadError.notFlac {
                // Fallback for when the song metadata isn't supported
                let avEnum = PlayerEnum.AVPlayer(.init(url: url), url)
                return avEnum.getSong()
            } else {
                throw error
            }
        }

    }


}
