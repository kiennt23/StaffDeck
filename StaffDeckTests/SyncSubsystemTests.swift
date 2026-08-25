import XCTest
@testable import StaffDeck

@MainActor
final class SyncSubsystemTests: XCTestCase {
    private let credentials = TursoCredentials(databaseURL: "libsql://test", authToken: "token")

    func testInjectedClockProducesStrictCanonicalMilliseconds() throws {
        let clock = FixedDateSource(Date(timeIntervalSince1970: 100.1239))
        let harness = try makeHarness(clock: clock)

        XCTAssertEqual(AppModel.milliseconds(clock.date), 100_123)

        harness.model.savePractice(itemID: "one", status: .attempted, score: nil, notes: "first")
        harness.model.savePractice(itemID: "one", status: .attempted, score: nil, notes: "second")

        XCTAssertEqual(AppModel.milliseconds(try XCTUnwrap(harness.model.practiceRecords["one"]?.updatedAt)), 100_124)
        XCTAssertEqual(harness.model.pendingMutationCount, 1)
    }

    func testLegacyCacheWithoutOutboxRestores() throws {
        let cache = MemoryStateCache()
        let record = ReviewRecord(
            cardID: 7, dueAt: Date(timeIntervalSince1970: 20), intervalDays: 2,
            rating: .good, reviews: 1, updatedAt: Date(timeIntervalSince1970: 10)
        )
        let legacy = LegacyCachedState(
            reviews: [7: record], flashcardWork: nil, practice: [:], profile: Defaults.profile,
            stories: Defaults.stories, companies: [], contacts: [], applications: []
        )
        cache.storage["staff-deck-native-cache-v1"] = try SyncCoding.encoder.encode(legacy)

        let harness = try makeHarness(cache: cache)

        XCTAssertEqual(harness.model.reviews[7], record)
        XCTAssertTrue(harness.model.flashcardWork.isEmpty)
        XCTAssertEqual(harness.model.pendingMutationCount, 0)
    }

    func testOfflineSaveCachesPreencodedEnvelopeWithoutNetwork() async throws {
        let harness = try makeHarness()

        harness.model.rate(cardID: 42, rating: .good, now: Date(timeIntervalSince1970: 200))

        let cached = try decodeCache(harness.cache)
        let calls = await harness.store.calls()
        XCTAssertEqual(cached.pendingMutations.count, 1)
        XCTAssertEqual(cached.pendingMutations[0].recordID, "42")
        XCTAssertTrue(calls.isEmpty)
    }

    func testFailedMutationRetainsOutboxAndUsesDeterministicDelays() async throws {
        let harness = try makeHarness(credential: credentials)
        harness.model.rate(cardID: 8, rating: .hard, now: Date(timeIntervalSince1970: 300))
        await harness.store.failNextUpserts(3)

        await harness.model.syncNow()

        let calls = await harness.store.calls()
        let delays = await harness.sleeper.recordedDelays()
        XCTAssertEqual(harness.model.pendingMutationCount, 1)
        XCTAssertEqual(calls.filter { $0.recordID == "8" }.count, 3)
        XCTAssertEqual(delays, [.milliseconds(250), .seconds(1)])
        guard case .offline = harness.model.syncState else { return XCTFail("Expected offline state") }
    }

    func testReconnectFlushesMutationRetainedAfterFailure() async throws {
        let harness = try makeHarness(credential: credentials)
        harness.model.rate(cardID: 9, rating: .easy, now: Date(timeIntervalSince1970: 400))
        await harness.store.failNextUpserts(3)
        await harness.model.syncNow()

        await harness.model.syncNow()

        let calls = await harness.store.calls()
        XCTAssertEqual(harness.model.pendingMutationCount, 0)
        XCTAssertEqual(calls.filter { $0.recordID == "9" }.count, 4)
        guard case .connected = harness.model.syncState else { return XCTFail("Expected connected state") }
    }

    func testRestartRestoresDurableOutboxAndFlushesMutation() async throws {
        let cache = MemoryStateCache()
        let offline = try makeHarness(cache: cache)
        offline.model.rate(cardID: 12, rating: .good, now: Date(timeIntervalSince1970: 450))

        let restarted = try makeHarness(cache: cache, credential: credentials)

        XCTAssertEqual(restarted.model.reviews[12]?.rating, .good)
        XCTAssertEqual(restarted.model.pendingMutationCount, 1)
        await restarted.model.syncNow()

        let calls = await restarted.store.calls()
        let cached = try decodeCache(cache)
        XCTAssertEqual(calls.filter { $0.recordID == "12" }.count, 1)
        XCTAssertEqual(restarted.model.pendingMutationCount, 0)
        XCTAssertTrue(cached.pendingMutations.isEmpty)
    }

    func testOlderAcknowledgementCannotReplaceNewerInFlightMutation() async throws {
        let harness = try makeHarness(credential: credentials)
        await harness.model.syncNow()
        await harness.store.pauseNextUpsert()

        let mutationDate = Date(timeIntervalSince1970: 600)
        harness.model.rate(cardID: 11, rating: .hard, now: mutationDate)
        let older = await harness.store.waitForPausedUpsert()
        harness.model.rate(cardID: 11, rating: .easy, now: mutationDate)
        let newer = try XCTUnwrap(harness.model.pendingMutations[older.key])
        await harness.store.pauseNextUpsert()
        let flushTask = harness.model.flushTask

        await harness.store.resumePausedUpsert()
        let retried = await harness.store.waitForPausedUpsert()

        XCTAssertGreaterThan(newer.updatedAtMilliseconds, older.updatedAtMilliseconds)
        XCTAssertEqual(retried, newer)
        XCTAssertEqual(harness.model.reviews[11]?.rating, .easy)
        XCTAssertEqual(harness.model.pendingMutations[older.key], newer)
        XCTAssertEqual(try decodeCache(harness.cache).pendingMutations, [newer])

        await harness.store.resumePausedUpsert()
        await flushTask?.value
        XCTAssertEqual(harness.model.reviews[11]?.rating, .easy)
        XCTAssertEqual(harness.model.pendingMutationCount, 0)
    }

    func testRemoteNewerRecordWinsAndDropsPendingMutation() async throws {
        let local = ReviewRecord(
            cardID: 10, dueAt: Date(timeIntervalSince1970: 500), intervalDays: 2,
            rating: .good, reviews: 1, updatedAt: Date(timeIntervalSince1970: 500)
        )
        var remote = local
        remote.rating = .easy
        remote.updatedAt = Date(timeIntervalSince1970: 501)
        let envelope = try SyncEnvelope.encode(
            remote, collection: .reviews, recordID: "10", updatedAtMilliseconds: 501_000
        )
        let harness = try makeHarness(rows: baselineRows() + [envelope], credential: credentials)
        harness.model.rate(cardID: 10, rating: .good, now: local.updatedAt)

        await harness.model.syncNow()

        let calls = await harness.store.calls()
        XCTAssertEqual(harness.model.reviews[10]?.rating, .easy)
        XCTAssertEqual(harness.model.pendingMutationCount, 0)
        XCTAssertTrue(calls.allSatisfy { $0.recordID != "10" })
    }

    func testCareerTombstoneSurvivesOlderRemoteAndFlushesDeletedMetadata() async throws {
        let harness = try makeHarness(rows: baselineRows(), credential: credentials)
        let story = try XCTUnwrap(harness.model.stories.first)

        harness.model.deleteStory(story)
        await harness.model.syncNow()

        let tombstone = try XCTUnwrap(harness.model.stories.first { $0.id == story.id })
        let calls = await harness.store.calls()
        XCTAssertTrue(tombstone.isDeleted)
        XCTAssertEqual(harness.model.pendingMutationCount, 0)
        let sent = try XCTUnwrap(calls.last { $0.recordID == story.id })
        XCTAssertTrue(sent.isDeleted)
    }

    private func makeHarness(
        rows: [SyncEnvelope]? = nil,
        cache: MemoryStateCache? = nil,
        clock: FixedDateSource? = nil,
        credential: TursoCredentials? = nil
    ) throws -> Harness {
        let cache = cache ?? MemoryStateCache()
        let clock = clock ?? FixedDateSource(Date(timeIntervalSince1970: 1_000))
        let initialRows = try rows ?? baselineRows()
        let store = FakeSyncStore(rows: initialRows)
        let sleeper = RecordingSleeper()
        let dependencies = AppDependencies(
            syncStore: store, cache: cache, credentials: MemoryCredentialsStore(credential),
            dateSource: clock, retrySleeper: sleeper
        )
        return Harness(model: AppModel(dependencies: dependencies), store: store, cache: cache, sleeper: sleeper)
    }

    private func baselineRows() throws -> [SyncEnvelope] {
        var rows = [try SyncEnvelope.encode(
            Defaults.profile, collection: .profile, recordID: "default",
            updatedAtMilliseconds: AppModel.milliseconds(Defaults.profile.updatedAt)
        )]
        rows += try Defaults.stories.map {
            try SyncEnvelope.encode(
                $0, collection: .stories, recordID: $0.id,
                updatedAtMilliseconds: AppModel.milliseconds($0.updatedAt)
            )
        }
        return rows
    }

    private func decodeCache(_ cache: MemoryStateCache) throws -> CachedState {
        let data = try XCTUnwrap(cache.storage["staff-deck-native-cache-v1"])
        return try SyncCoding.decoder.decode(CachedState.self, from: data)
    }
}

private struct Harness {
    let model: AppModel
    let store: FakeSyncStore
    let cache: MemoryStateCache
    let sleeper: RecordingSleeper
}
