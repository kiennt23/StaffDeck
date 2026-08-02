import Foundation
import Libsql

actor TursoStore {
    private var database: Database?
    private var connection: Connection?

    func connect(credentials: TursoCredentials) throws {
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

    func disconnect() {
        connection = nil
        database = nil
    }

    func load<T: Decodable>(_ type: T.Type, collection: String) throws -> [T] {
        guard let connection else { throw TursoError.notConnected }
        let rows = try connection.query(
            """
            SELECT payload
            FROM synced_records
            WHERE collection = ?
            ORDER BY updated_at ASC
            """,
            [Value.text(collection)]
        )
        let decoder = Self.decoder
        return try rows.compactMap { row in
            let payload = try row.getString(0)
            return try decoder.decode(T.self, from: Data(payload.utf8))
        }
    }

    func upsert<T: Encodable>(
        _ value: T,
        collection: String,
        id: String,
        updatedAt: Date,
        isDeleted: Bool = false
    ) throws {
        guard let connection else { throw TursoError.notConnected }
        let data = try Self.encoder.encode(value)
        guard let payload = String(data: data, encoding: .utf8) else {
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
                Value.text(collection),
                Value.text(id),
                Value.text(payload),
                Value.integer(Int64(updatedAt.timeIntervalSince1970 * 1_000)),
                Value.integer(isDeleted ? 1 : 0),
            ]
        )
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

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
        case .driver(let detail):
            "Turso connection failed: \(detail)"
        }
    }
}
