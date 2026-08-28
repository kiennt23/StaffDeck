import Foundation

extension AppModel {
    func ensureFlush() {
        guard case .connected = syncState, flushTask == nil, !pendingMutations.isEmpty else { return }
        let generation = syncGeneration
        flushTask = Task { [weak self] in
            await self?.flush(generation: generation)
        }
    }

    private func flush(generation: Int) async {
        while generation == syncGeneration, !Task.isCancelled,
              let attempted = pendingMutations.values.sorted(by: Self.outboxOrder).first {
            var acknowledged = false
            for attempt in 0..<3 {
                guard generation == syncGeneration, !Task.isCancelled else { return }
                guard pendingMutations[attempted.key] == attempted else { break }
                do {
                    let authoritative = try await dependencies.syncStore.upsert(attempted)
                    guard generation == syncGeneration, !Task.isCancelled else { return }
                    try acknowledge(attempted, authoritative: authoritative)
                    acknowledged = true
                    break
                } catch {
                    guard generation == syncGeneration, !Task.isCancelled else { return }
                    guard pendingMutations[attempted.key] == attempted else { break }
                    if attempt == 2 {
                        syncState = .offline(error.localizedDescription)
                        flushTask = nil
                        return
                    }
                    let delay: Duration = attempt == 0 ? .milliseconds(250) : .seconds(1)
                    do {
                        try await dependencies.retrySleeper.sleep(for: delay)
                    } catch {
                        return
                    }
                }
            }
            if !acknowledged, pendingMutations[attempted.key] == attempted { break }
        }
        guard generation == syncGeneration else { return }
        flushTask = nil
    }

    private func acknowledge(
        _ attempted: SyncEnvelope,
        authoritative: SyncEnvelope
    ) throws {
        guard authoritative.key == attempted.key else { throw SyncPipelineError.mismatchedAuthority }
        guard authoritative.updatedAtMilliseconds >= attempted.updatedAtMilliseconds else {
            throw SyncPipelineError.staleAuthority
        }
        if pendingMutations[attempted.key] == attempted {
            try applyRemote(authoritative)
            pendingMutations.removeValue(forKey: attempted.key)
        }
        try persistCache()
        syncState = .connected(dependencies.dateSource.now())
    }

    func applyRemote(_ envelope: SyncEnvelope) throws {
        switch envelope.collection {
        case .reviews:
            var value = try envelope.decode(ReviewRecord.self)
            value.updatedAt = Self.date(envelope.updatedAtMilliseconds)
            reviews[value.cardID] = value
        case .flashcardWork:
            var value = try envelope.decode(FlashcardWork.self)
            value.updatedAt = Self.date(envelope.updatedAtMilliseconds)
            flashcardWork[value.cardID] = value
        case .practice:
            var value = try envelope.decode(PracticeRecord.self)
            value.updatedAt = Self.date(envelope.updatedAtMilliseconds)
            practiceRecords[value.practiceID] = value
        case .practiceAttempts:
            var value = try envelope.decode(PracticeAttempt.self)
            value.updatedAt = Self.date(envelope.updatedAtMilliseconds)
            var list = practiceAttempts[value.practiceID] ?? []
            if let idx = list.firstIndex(where: { $0.id == value.id }) {
                list[idx] = value
            } else {
                list.append(value)
            }
            practiceAttempts[value.practiceID] = list
        case .profile:
            var value = try envelope.decode(CareerProfile.self)
            value.updatedAt = Self.date(envelope.updatedAtMilliseconds)
            profile = value
        case .stories:
            stories = try applyingCareer(envelope, to: stories)
        case .companies:
            companies = try applyingCareer(envelope, to: companies)
        case .contacts:
            contacts = try applyingCareer(envelope, to: contacts)
        case .applications:
            applications = try applyingCareer(envelope, to: applications)
        }
    }

    private func applyingCareer<Value: CareerRecord>(
        _ envelope: SyncEnvelope,
        to records: [Value]
    ) throws -> [Value] {
        var result = records
        var value = try envelope.decode(Value.self)
        value.updatedAt = Self.date(envelope.updatedAtMilliseconds)
        value.isDeleted = envelope.isDeleted
        if let index = result.firstIndex(where: { $0.id == value.id }) {
            result[index] = value
        } else {
            result.append(value)
        }
        return result
    }
}

enum SyncPipelineError: LocalizedError {
    case mismatchedAuthority
    case staleAuthority

    var errorDescription: String? {
        switch self {
        case .mismatchedAuthority: "Turso acknowledged a different synced record."
        case .staleAuthority: "Turso returned an older synced record after an upsert."
        }
    }
}
