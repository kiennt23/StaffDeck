import Foundation

enum SyncCollection: String, Codable, CaseIterable, Sendable {
    case reviews = "flashcard-progress"
    case flashcardWork = "flashcard-work"
    case practice = "practice-progress"
    case profile = "career-profile"
    case stories = "career-stories"
    case companies = "career-companies"
    case contacts = "career-contacts"
    case applications = "career-applications"
}

struct SyncKey: Hashable, Sendable {
    let collection: SyncCollection
    let recordID: String
}

struct SyncEnvelope: Codable, Equatable, Sendable {
    let collection: SyncCollection
    let recordID: String
    let payload: Data
    let updatedAtMilliseconds: Int64
    let isDeleted: Bool

    var key: SyncKey {
        SyncKey(collection: collection, recordID: recordID)
    }
}

protocol SyncStore: Sendable {
    func connect(credentials: TursoCredentials) async throws
    func disconnect() async
    func load(collection: SyncCollection) async throws -> [SyncEnvelope]
    func upsert(_ mutation: SyncEnvelope) async throws -> SyncEnvelope
}

extension SyncEnvelope {
    static func encode<Value: Encodable>(
        _ value: Value,
        collection: SyncCollection,
        recordID: String,
        updatedAtMilliseconds: Int64,
        isDeleted: Bool = false
    ) throws -> SyncEnvelope {
        SyncEnvelope(
            collection: collection,
            recordID: recordID,
            payload: try SyncCoding.encoder.encode(value),
            updatedAtMilliseconds: updatedAtMilliseconds,
            isDeleted: isDeleted
        )
    }

    func decode<Value: Decodable>(_ type: Value.Type) throws -> Value {
        try SyncCoding.decoder.decode(type, from: payload)
    }
}

enum SyncCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
