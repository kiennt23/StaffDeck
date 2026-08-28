import Foundation

extension AppModel {
    func reconcileAll(_ remote: RemoteSnapshot) throws {
        reviews = try reconcile(
            local: Array(reviews.values), remote: remote[.reviews], collection: .reviews,
            id: { String($0.cardID) }, updatedAt: \.updatedAt
        ).reduce(into: [:]) { $0[$1.cardID] = $1 }
        flashcardWork = try reconcile(
            local: Array(flashcardWork.values), remote: remote[.flashcardWork],
            collection: .flashcardWork, id: { String($0.cardID) }, updatedAt: \.updatedAt
        ).reduce(into: [:]) { $0[$1.cardID] = $1 }
        practiceRecords = try reconcile(
            local: Array(practiceRecords.values), remote: remote[.practice], collection: .practice,
            id: \.practiceID, updatedAt: \.updatedAt
        ).reduce(into: [:]) { $0[$1.practiceID] = $1 }
        let allAttempts = try reconcile(
            local: practiceAttempts.values.flatMap { $0 }, remote: remote[.practiceAttempts],
            collection: .practiceAttempts, id: \.id, updatedAt: \.updatedAt
        )
        practiceAttempts = Dictionary(grouping: allAttempts, by: \.practiceID)
        normalizePracticeState()
        profile = try reconcile(
            local: [profile], remote: remote[.profile], collection: .profile,
            id: { _ in "default" }, updatedAt: \.updatedAt
        ).first ?? profile
        stories = try reconcileCareer(stories, remote: remote[.stories], collection: .stories)
        companies = try reconcileCareer(companies, remote: remote[.companies], collection: .companies)
        contacts = try reconcileCareer(contacts, remote: remote[.contacts], collection: .contacts)
        applications = try reconcileCareer(
            applications, remote: remote[.applications], collection: .applications
        )
    }

    private func reconcileCareer<Value: CareerRecord>(
        _ local: [Value],
        remote: [SyncEnvelope],
        collection: SyncCollection
    ) throws -> [Value] {
        try reconcile(
            local: local,
            remote: remote,
            collection: collection,
            id: \.id,
            updatedAt: \.updatedAt,
            isDeleted: \.isDeleted
        )
    }

    private func reconcile<Value: Codable>(
        local: [Value],
        remote: [SyncEnvelope],
        collection: SyncCollection,
        id: KeyPath<Value, String>,
        updatedAt: WritableKeyPath<Value, Date>,
        isDeleted: WritableKeyPath<Value, Bool>? = nil
    ) throws -> [Value] {
        try reconcile(
            local: local,
            remote: remote,
            collection: collection,
            id: { $0[keyPath: id] },
            updatedAt: updatedAt,
            isDeleted: isDeleted
        )
    }

    private func reconcile<Value: Codable>(
        local: [Value],
        remote: [SyncEnvelope],
        collection: SyncCollection,
        id: (Value) -> String,
        updatedAt: WritableKeyPath<Value, Date>,
        isDeleted: WritableKeyPath<Value, Bool>? = nil
    ) throws -> [Value] {
        var localValues: [String: Value] = [:]
        var localEnvelopes: [String: SyncEnvelope] = [:]
        for value in local {
            let recordID = id(value)
            localValues[recordID] = value
            localEnvelopes[recordID] = try SyncEnvelope.encode(
                value,
                collection: collection,
                recordID: recordID,
                updatedAtMilliseconds: Self.milliseconds(value[keyPath: updatedAt]),
                isDeleted: isDeleted.map { value[keyPath: $0] } ?? false
            )
        }
        var remoteValues: [String: SyncEnvelope] = [:]
        for value in remote where value.collection == collection {
            if let previous = remoteValues[value.recordID],
               previous.updatedAtMilliseconds > value.updatedAtMilliseconds { continue }
            remoteValues[value.recordID] = value
        }

        let pendingIDs = pendingMutations.keys
            .filter { $0.collection == collection }
            .map(\.recordID)
        let recordIDs = Set(localValues.keys).union(remoteValues.keys).union(pendingIDs)
        var merged: [String: Value] = [:]
        for recordID in recordIDs {
            let key = SyncKey(collection: collection, recordID: recordID)
            let localEnvelope = localEnvelopes[recordID]
            let pending = pendingMutations[key]
            let localWinner = preferredLocal(pending, localEnvelope)
            if let cloud = remoteValues[recordID],
               localWinner == nil || cloud.updatedAtMilliseconds >= localWinner!.updatedAtMilliseconds {
                merged[recordID] = try decoded(
                    cloud, updatedAt: updatedAt, isDeleted: isDeleted
                )
                if let pending, pending.updatedAtMilliseconds <= cloud.updatedAtMilliseconds {
                    pendingMutations.removeValue(forKey: key)
                }
            } else if let winner = localWinner {
                if winner == localEnvelope, let value = localValues[recordID] {
                    merged[recordID] = value
                } else {
                    merged[recordID] = try decoded(
                        winner, updatedAt: updatedAt, isDeleted: isDeleted
                    )
                }
                pendingMutations[key] = winner
            }
        }
        return recordIDs.sorted().compactMap { merged[$0] }
    }

    private func preferredLocal(
        _ pending: SyncEnvelope?,
        _ local: SyncEnvelope?
    ) -> SyncEnvelope? {
        guard let pending else { return local }
        guard let local else { return pending }
        return pending.updatedAtMilliseconds >= local.updatedAtMilliseconds ? pending : local
    }

    private func decoded<Value: Decodable>(
        _ envelope: SyncEnvelope,
        updatedAt: WritableKeyPath<Value, Date>,
        isDeleted: WritableKeyPath<Value, Bool>?
    ) throws -> Value {
        var value = try envelope.decode(Value.self)
        value[keyPath: updatedAt] = Self.date(envelope.updatedAtMilliseconds)
        if let isDeleted { value[keyPath: isDeleted] = envelope.isDeleted }
        return value
    }
}
