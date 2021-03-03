import GRDB
import Combine
import Foundation

class AppDatabase: ObservableObject
{
    public var dbWriter: DatabaseWriter

    init(dbWriter: DatabaseWriter) throws
    {
        self.dbWriter = dbWriter
        try self.migrator.migrate(self.dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Speed up development by nuking the database when migrations change
        // See https://github.com/groue/GRDB.swift/blob/master/Documentation/Migrations.md#the-erasedatabaseonschemachange-option
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("createAlbum") { db in
            try db.create(table: "album", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("cover", .blob)
            }

        }

        migrator.registerMigration("createSong") {db in
            try db.create(table: "song") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cover", .blob)
                t.column("bookmark", .blob).unique()
                t.column("metadata", .blob).unique()
                t.column("albumID", .integer)
                t.foreignKey(["albumID"], references: "album", columns: ["id"])
            }
        }

        return migrator
    }
}

// MARK : singleton
extension AppDatabase {
    public static let shared = makeShared()

    private static func makeShared() -> AppDatabase
    {
        do {
            // Create a folder for storing the SQLite database, as well as
            // the various temporary files created during normal database
            // operations (https://sqlite.org/tempfiles.html).
            let fileManager = FileManager()
            let folderURL = try fileManager
                    .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("database", isDirectory: true)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

            // Connect to a database on disk
            // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
            let dbURL = folderURL.appendingPathComponent("db.sqlite")
            let dbPool = try DatabasePool(path: dbURL.path)

            // Create the AppDatabase
            let appDatabase = try AppDatabase(dbWriter: dbPool)

            return appDatabase
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate.
            //
            // Typical reasons for an error here include:
            // * The parent directory cannot be created, or disallows writing.
            // * The database is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The database could not be migrated to its latest schema version.
            // Check the error message to determine what the actual problem was.
            fatalError("Unresolved error \(error)")
        }
    }
}