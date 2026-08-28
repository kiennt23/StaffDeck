import Foundation

@MainActor
protocol StateCache {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func removeObject(forKey key: String)
}

@MainActor
protocol CredentialsStore {
    func load() -> TursoCredentials?
    func save(_ credentials: TursoCredentials) throws
    func delete()
}

@MainActor
protocol DateSource {
    func now() -> Date
}

protocol RetrySleeper: Sendable {
    func sleep(for delay: Duration) async throws
}

@MainActor
struct AppDependencies {
    let syncStore: any SyncStore
    let cache: any StateCache
    let credentials: any CredentialsStore
    let dateSource: any DateSource
    let calendar: Calendar
    let retrySleeper: any RetrySleeper

    static var live: AppDependencies {
        AppDependencies(
            syncStore: TursoStore(),
            cache: UserDefaultsStateCache(defaults: .standard),
            credentials: KeychainCredentialsStore(),
            dateSource: SystemDateSource(),
            calendar: Calendar(identifier: .gregorian),
            retrySleeper: TaskRetrySleeper()
        )
    }
}

@MainActor
struct UserDefaultsStateCache: StateCache {
    let defaults: UserDefaults

    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func set(_ data: Data, forKey key: String) { defaults.set(data, forKey: key) }
    func removeObject(forKey key: String) { defaults.removeObject(forKey: key) }
}

@MainActor
struct KeychainCredentialsStore: CredentialsStore {
    func load() -> TursoCredentials? { KeychainStore.load() }
    func save(_ credentials: TursoCredentials) throws { try KeychainStore.save(credentials) }
    func delete() { KeychainStore.delete() }
}

@MainActor
struct SystemDateSource: DateSource {
    func now() -> Date { Date() }
}

struct TaskRetrySleeper: RetrySleeper {
    func sleep(for delay: Duration) async throws {
        try await Task.sleep(for: delay)
    }
}
