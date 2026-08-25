import Foundation
@testable import StaffDeck

actor FakeSyncStore: SyncStore {
    private var rows: [SyncKey: SyncEnvelope]
    private var failuresRemaining = 0
    private var shouldPauseNextUpsert = false
    private var pausedMutation: SyncEnvelope?
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var pauseObservers: [CheckedContinuation<SyncEnvelope, Never>] = []
    private(set) var upsertCalls: [SyncEnvelope] = []
    private(set) var connectCalls = 0

    init(rows: [SyncEnvelope] = []) {
        self.rows = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0) })
    }

    func connect(credentials: TursoCredentials) async throws {
        connectCalls += 1
    }

    func disconnect() async {}

    func load(collection: SyncCollection) async throws -> [SyncEnvelope] {
        rows.values.filter { $0.collection == collection }
    }

    func upsert(_ mutation: SyncEnvelope) async throws -> SyncEnvelope {
        upsertCalls.append(mutation)
        if shouldPauseNextUpsert {
            shouldPauseNextUpsert = false
            pausedMutation = mutation
            let observers = pauseObservers
            pauseObservers.removeAll()
            observers.forEach { $0.resume(returning: mutation) }
            await withCheckedContinuation { pauseContinuation = $0 }
        }
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw FakeSyncError.upsertFailed
        }
        if let existing = rows[mutation.key],
           existing.updatedAtMilliseconds > mutation.updatedAtMilliseconds {
            return existing
        }
        rows[mutation.key] = mutation
        return mutation
    }

    func failNextUpserts(_ count: Int) {
        failuresRemaining = count
    }

    func pauseNextUpsert() {
        shouldPauseNextUpsert = true
    }

    func waitForPausedUpsert() async -> SyncEnvelope {
        if let pausedMutation { return pausedMutation }
        return await withCheckedContinuation { pauseObservers.append($0) }
    }

    func resumePausedUpsert() {
        pausedMutation = nil
        let continuation = pauseContinuation
        pauseContinuation = nil
        continuation?.resume()
    }

    func calls() -> [SyncEnvelope] { upsertCalls }
}

enum FakeSyncError: LocalizedError {
    case upsertFailed
    var errorDescription: String? { "Scripted upsert failure" }
}

@MainActor
final class MemoryStateCache: StateCache {
    var storage: [String: Data] = [:]
    private(set) var writes = 0

    func data(forKey key: String) -> Data? { storage[key] }
    func set(_ data: Data, forKey key: String) {
        writes += 1
        storage[key] = data
    }
    func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
}

@MainActor
final class MemoryCredentialsStore: CredentialsStore {
    var credentials: TursoCredentials?
    init(_ credentials: TursoCredentials? = nil) { self.credentials = credentials }
    func load() -> TursoCredentials? { credentials }
    func save(_ credentials: TursoCredentials) throws { self.credentials = credentials }
    func delete() { credentials = nil }
}

@MainActor
final class FixedDateSource: DateSource {
    var date: Date
    init(_ date: Date) { self.date = date }
    func now() -> Date { date }
}

actor RecordingSleeper: RetrySleeper {
    private(set) var delays: [Duration] = []
    func sleep(for delay: Duration) async throws { delays.append(delay) }
    func recordedDelays() -> [Duration] { delays }
}

struct LegacyCachedState: Codable {
    var reviews: [Int: ReviewRecord]
    var flashcardWork: [Int: FlashcardWork]?
    var practice: [String: PracticeRecord]
    var profile: CareerProfile
    var stories: [StaffStory]
    var companies: [TargetCompany]
    var contacts: [Contact]
    var applications: [JobApplication]
}
