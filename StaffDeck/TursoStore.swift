import Foundation
import Libsql

actor TursoStore: SyncStore {
    private var database: Database?
    private var connection: Connection?

    func connect(credentials: TursoCredentials) async throws {
        let trimmedURL = credentials.databaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = credentials.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmedURL),
            ["libsql", "https"].contains(url.scheme?.lowercased() ?? ""),
            !trimmedToken.isEmpty
        else {
            throw TursoError.invalidCredentials
        }

        guard
            let schemaURL = Bundle.main.url(forResource: "schema", withExtension: "sql"),
            let schema = try? String(contentsOf: schemaURL, encoding: .utf8)
        else {
            throw TursoError.missingSchema
        }

        do {
            let database = try Database(
                url: trimmedURL,
                authToken: trimmedToken,
                withWebpki: Self.requiresBundledCertificateRoots
            )
            let connection = try database.connect()
            _ = try connection.query("SELECT 1").next()
            try connection.executeBatch(schema)
            self.database = database
            self.connection = connection
        } catch {
            throw TursoError.driver(String(describing: error))
        }
    }

    func disconnect() async {
        connection = nil
        database = nil
    }

    func load(collection: SyncCollection) async throws -> [SyncEnvelope] {
        guard let connection else { throw TursoError.notConnected }
        let rows = try connection.query(
            """
            SELECT record_id, payload, updated_at, is_deleted
            FROM synced_records
            WHERE collection = ?
            ORDER BY updated_at ASC
            """,
            [Value.text(collection.rawValue)]
        )
        return try rows.map { row in
            SyncEnvelope(
                collection: collection,
                recordID: try row.getString(0),
                payload: Data(try row.getString(1).utf8),
                updatedAtMilliseconds: try Self.integer(row, at: 2),
                isDeleted: try Self.integer(row, at: 3) != 0
            )
        }
    }

    func upsert(_ mutation: SyncEnvelope) async throws -> SyncEnvelope {
        guard let connection else { throw TursoError.notConnected }
        guard let payload = String(data: mutation.payload, encoding: .utf8) else {
            throw TursoError.encodingFailed
        }
        _ = try connection.execute(
            """
            INSERT INTO synced_records(collection, record_id, payload, updated_at, is_deleted)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(collection, record_id) DO UPDATE SET
                payload = excluded.payload,
                updated_at = excluded.updated_at,
                is_deleted = excluded.is_deleted
            WHERE excluded.updated_at >= synced_records.updated_at
            """,
            [
                Value.text(mutation.collection.rawValue),
                Value.text(mutation.recordID),
                Value.text(payload),
                Value.integer(mutation.updatedAtMilliseconds),
                Value.integer(mutation.isDeleted ? 1 : 0),
            ]
        )
        let rows = try connection.query(
            """
            SELECT record_id, payload, updated_at, is_deleted
            FROM synced_records
            WHERE collection = ? AND record_id = ?
            """,
            [Value.text(mutation.collection.rawValue), Value.text(mutation.recordID)]
        )
        guard let row = rows.next() else { throw TursoError.missingAuthoritativeRow }
        return SyncEnvelope(
            collection: mutation.collection,
            recordID: try row.getString(0),
            payload: Data(try row.getString(1).utf8),
            updatedAtMilliseconds: try Self.integer(row, at: 2),
            isDeleted: try Self.integer(row, at: 3) != 0
        )
    }

    private static func integer(_ row: Row, at index: Int32) throws -> Int64 {
        guard case .integer(let value) = try row.get(index) else {
            throw TursoError.invalidRow
        }
        return value
    }

    private static var requiresBundledCertificateRoots: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
}

enum TursoError: LocalizedError {
    case invalidCredentials
    case missingSchema
    case notConnected
    case encodingFailed
    case missingAuthoritativeRow
    case invalidRow
    case driver(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Enter a libsql:// or https:// Turso database URL and a database auth token."
        case .missingSchema:
            "The bundled Turso schema could not be loaded."
        case .notConnected:
            "Staff Deck is not connected to Turso."
        case .encodingFailed:
            "A local record could not be encoded for sync."
        case .missingAuthoritativeRow:
            "Turso did not return the synced record after an upsert."
        case .invalidRow:
            "Turso returned a synced record with an invalid integer field."
        case .driver(let detail):
            "Turso connection failed: \(detail)"
        }
    }
}
