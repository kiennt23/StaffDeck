import Foundation

extension AppModel {
    func enqueue<Value: Encodable>(
        _ value: Value,
        key: SyncKey,
        milliseconds: Int64,
        isDeleted: Bool = false
    ) {
        do {
            let mutation = try SyncEnvelope.encode(
                value,
                collection: key.collection,
                recordID: key.recordID,
                updatedAtMilliseconds: milliseconds,
                isDeleted: isDeleted
            )
            pendingMutations[key] = mutation
            try persistCache()
            ensureFlush()
        } catch {
            syncState = .offline("Local mutation could not be cached: \(error.localizedDescription)")
        }
    }

    func nextMilliseconds(
        key: SyncKey,
        current: Date?,
        candidate: Date? = nil
    ) -> Int64 {
        let clock = candidate ?? dependencies.dateSource.now()
        let candidateMilliseconds = Self.milliseconds(clock)
        let currentMilliseconds = current.map(Self.milliseconds) ?? Int64.min
        let pendingMilliseconds = pendingMutations[key]?.updatedAtMilliseconds ?? Int64.min
        let afterCurrent = currentMilliseconds == Int64.min ? Int64.min : currentMilliseconds + 1
        let afterPending = pendingMilliseconds == Int64.min ? Int64.min : pendingMilliseconds + 1
        return max(candidateMilliseconds, max(afterCurrent, afterPending))
    }

    static func milliseconds(_ date: Date) -> Int64 {
        let value = date.timeIntervalSince1970 * 1_000
        return Int64(floor(value + 0.0001))
    }

    static func date(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
    }
}
