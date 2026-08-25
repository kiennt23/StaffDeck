import Foundation

extension AppModel {
    func start() async {
        guard let credentials = dependencies.credentials.load() else {
            syncState = .notConfigured
            return
        }
        await connect(credentials)
    }

    func connect(_ credentials: TursoCredentials) async {
        syncGeneration += 1
        let generation = syncGeneration
        await cancelFlush()
        guard generation == syncGeneration else { return }
        syncState = .connecting

        do {
            try await dependencies.syncStore.connect(credentials: credentials)
            guard generation == syncGeneration else { return }
            try dependencies.credentials.save(credentials)
            let snapshot = try await loadRemoteSnapshot()
            guard generation == syncGeneration else { return }
            let stateBeforeReconcile = cachedState()
            do {
                try reconcileAll(snapshot)
                try persistCache()
            } catch {
                applyCachedState(stateBeforeReconcile)
                throw error
            }
            syncState = .connected(dependencies.dateSource.now())
            ensureFlush()
            let task = flushTask
            await task?.value
        } catch {
            guard generation == syncGeneration else { return }
            syncState = .offline(error.localizedDescription)
        }
    }

    func disconnectAndForget() async {
        syncGeneration += 1
        let generation = syncGeneration
        await cancelFlush()
        await dependencies.syncStore.disconnect()
        guard generation == syncGeneration else { return }
        dependencies.credentials.delete()
        syncState = .notConfigured
    }

    func syncNow() async {
        guard let credentials = dependencies.credentials.load() else {
            syncState = .notConfigured
            return
        }
        await connect(credentials)
    }

    func cancelFlush() async {
        let task = flushTask
        flushTask = nil
        task?.cancel()
        await task?.value
    }

    private func loadRemoteSnapshot() async throws -> RemoteSnapshot {
        var rows: [SyncCollection: [SyncEnvelope]] = [:]
        for collection in SyncCollection.allCases {
            rows[collection] = try await dependencies.syncStore.load(collection: collection)
        }
        return RemoteSnapshot(rows: rows)
    }
}

struct RemoteSnapshot {
    let rows: [SyncCollection: [SyncEnvelope]]

    subscript(_ collection: SyncCollection) -> [SyncEnvelope] {
        rows[collection] ?? []
    }
}
