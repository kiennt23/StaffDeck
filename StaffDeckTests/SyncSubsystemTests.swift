import XCTest
@testable import StaffDeck

@MainActor
final class SyncSubsystemTests: XCTestCase {
    private let credentials = TursoCredentials(databaseURL: "libsql://test", authToken: "token")

    func testInjectedClockProducesStrictCanonicalMilliseconds() throws {
        let clock = FixedDateSource(Date(timeIntervalSince1970: 100.1239))
        let harness = try makeHarness(clock: clock)

        XCTAssertEqual(AppModel.milliseconds(clock.date), 100_123)

        harness.model.savePracticeDraft(itemID: "one", status: .attempted, score: nil, notes: "first")
        harness.model.savePracticeDraft(itemID: "one", status: .attempted, score: nil, notes: "second")

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
        XCTAssertTrue(harness.model.practiceAttempts.isEmpty)
        XCTAssertEqual(harness.model.pendingMutationCount, 0)
    }

    func testSubmitPracticeRecordsImmutableAttemptAndEnqueuesOutbox() async throws {
        let harness = try makeHarness(credential: credentials)
        let practice = try XCTUnwrap(harness.model.practices.first { $0.id == "general-1.1" })
        let attempt = try harness.model.submitPracticeAttempt(
            itemID: practice.id,
            score: 4,
            notes: "great attempt",
            artifact: "solution artifact",
            satisfiedCriterionIDs: practice.completionCriteria.map(\.id)
        )

        let attempts = try XCTUnwrap(harness.model.practiceAttempts["general-1.1"])
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts[0].id, attempt.id)
        XCTAssertEqual(attempts[0].score, 4)
        XCTAssertEqual(attempts[0].status, .completed)
        XCTAssertEqual(attempts[0].notes, "great attempt")
        XCTAssertEqual(attempts[0].submission?.artifact, "solution artifact")
        XCTAssertEqual(attempts[0].submission?.satisfiedCriterionIDs, practice.completionCriteria.map(\.id))
        XCTAssertEqual(harness.model.practiceRecords["general-1.1"]?.attempts, 1)
        XCTAssertTrue(harness.model.hasSubmittedEvidence(for: "general-1.1"))

        // Both the latest summary record and the immutable attempt are enqueued
        XCTAssertEqual(harness.model.pendingMutationCount, 2)
        await harness.model.syncNow()
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

    // MARK: - Table-Driven Regression Tests

    func testPracticeDraftsMutationsAndNoOps() throws {
        let harness = try makeHarness()
        let practiceID = "general-1.1"

        struct DraftTestCase {
            let name: String
            let status: PracticeStatus
            let score: Int?
            let notes: String
            let artifact: String
            let criteria: [String]
            let expectMutation: Bool
            let expectedAttempts: Int
        }

        let cases: [DraftTestCase] = [
            DraftTestCase(name: "Empty default no-op", status: .notStarted, score: nil, notes: "", artifact: "", criteria: [], expectMutation: false, expectedAttempts: 0),
            DraftTestCase(name: "Notes only", status: .notStarted, score: nil, notes: "Just notes", artifact: "", criteria: [], expectMutation: true, expectedAttempts: 0),
            DraftTestCase(name: "Notes duplicate no-op", status: .notStarted, score: nil, notes: "Just notes", artifact: "", criteria: [], expectMutation: false, expectedAttempts: 0),
            DraftTestCase(name: "Score only", status: .notStarted, score: 3, notes: "Just notes", artifact: "", criteria: [], expectMutation: true, expectedAttempts: 0),
            DraftTestCase(name: "Status only", status: .attempted, score: 3, notes: "Just notes", artifact: "", criteria: [], expectMutation: true, expectedAttempts: 0),
            DraftTestCase(name: "Artifact only", status: .attempted, score: 3, notes: "Just notes", artifact: "func solve() {}", criteria: [], expectMutation: true, expectedAttempts: 0),
            DraftTestCase(name: "Criteria only", status: .attempted, score: 3, notes: "Just notes", artifact: "func solve() {}", criteria: ["legacy-completion"], expectMutation: true, expectedAttempts: 0),
            DraftTestCase(name: "Full duplicate no-op", status: .attempted, score: 3, notes: "Just notes", artifact: "func solve() {}", criteria: ["legacy-completion"], expectMutation: false, expectedAttempts: 0),
        ]

        for tc in cases {
            let beforeUpdatedAt = harness.model.practiceRecords[practiceID]?.updatedAt

            harness.model.savePracticeDraft(
                itemID: practiceID,
                status: tc.status,
                score: tc.score,
                notes: tc.notes,
                artifact: tc.artifact,
                satisfiedCriterionIDs: tc.criteria
            )

            if tc.expectMutation {
                XCTAssertEqual(harness.model.pendingMutationCount, 1, "Failed for case: \(tc.name)")
                let record = try XCTUnwrap(harness.model.practiceRecords[practiceID], "Failed for case: \(tc.name)")
                XCTAssertEqual(record.status, tc.status, "Failed for case: \(tc.name)")
                XCTAssertEqual(record.score, tc.score, "Failed for case: \(tc.name)")
                XCTAssertEqual(record.notes, tc.notes, "Failed for case: \(tc.name)")
                XCTAssertEqual(record.draftArtifact, tc.artifact, "Failed for case: \(tc.name)")
                XCTAssertEqual(record.draftSatisfiedCriterionIDs, tc.criteria, "Failed for case: \(tc.name)")
                XCTAssertEqual(record.attempts, tc.expectedAttempts, "Failed for case: \(tc.name)")
            } else {
                if let beforeUpdatedAt {
                    XCTAssertEqual(harness.model.practiceRecords[practiceID]?.updatedAt, beforeUpdatedAt, "No-op case \(tc.name) should not modify updatedAt")
                } else {
                    XCTAssertNil(harness.model.practiceRecords[practiceID], "Empty no-op case \(tc.name) should not create record")
                }
            }
            // Draft changes never create attempts
            XCTAssertTrue((harness.model.practiceAttempts[practiceID] ?? []).isEmpty, "Draft should never create attempts in \(tc.name)")
        }
    }

    func testSubmitPracticeAttemptValidationAndSideEffectFreedom() throws {
        let harness = try makeHarness()
        let practice = try XCTUnwrap(harness.model.practices.first { $0.id == "general-1.1" })
        let validCriterion = try XCTUnwrap(practice.completionCriteria.first?.id)

        struct InvalidSubmissionTestCase {
            let name: String
            let itemID: String
            let artifact: String
            let criteria: [String]
            let expectedError: PracticeSubmissionError
        }

        let invalidCases: [InvalidSubmissionTestCase] = [
            InvalidSubmissionTestCase(name: "Unknown practice ID", itemID: "unknown-practice-id-999", artifact: "valid artifact", criteria: ["legacy-completion"], expectedError: .unknownPractice("unknown-practice-id-999")),
            InvalidSubmissionTestCase(name: "Empty artifact", itemID: practice.id, artifact: "", criteria: [validCriterion], expectedError: .emptyArtifact),
            InvalidSubmissionTestCase(name: "Whitespace artifact", itemID: practice.id, artifact: "   \n\t  ", criteria: [validCriterion], expectedError: .emptyArtifact),
            InvalidSubmissionTestCase(name: "No criteria selected", itemID: practice.id, artifact: "valid artifact", criteria: [], expectedError: .noCriteriaSelected),
            InvalidSubmissionTestCase(name: "Invalid criterion ID", itemID: practice.id, artifact: "valid artifact", criteria: ["invalid-crit-id-123"], expectedError: .invalidCriterionID("invalid-crit-id-123")),
            InvalidSubmissionTestCase(name: "Mixed valid and invalid criteria", itemID: practice.id, artifact: "valid artifact", criteria: [validCriterion, "bogus-criterion"], expectedError: .invalidCriterionID("bogus-criterion")),
        ]

        for tc in invalidCases {
            let beforeRecords = harness.model.practiceRecords
            let beforeAttempts = harness.model.practiceAttempts
            let beforePending = harness.model.pendingMutations
            let beforeCacheWrites = harness.cache.writes

            XCTAssertThrowsError(
                try harness.model.submitPracticeAttempt(
                    itemID: tc.itemID,
                    score: 4,
                    notes: "test notes",
                    artifact: tc.artifact,
                    satisfiedCriterionIDs: tc.criteria
                ),
                "Expected error for case: \(tc.name)"
            ) { error in
                guard let subError = error as? PracticeSubmissionError else {
                    return XCTFail("Expected PracticeSubmissionError but got \(error)")
                }
                XCTAssertEqual(subError, tc.expectedError, "Error mismatch for case: \(tc.name)")
            }

            // Verify side-effect freedom
            XCTAssertEqual(harness.model.practiceRecords, beforeRecords, "Side-effect on records in \(tc.name)")
            XCTAssertEqual(harness.model.practiceAttempts, beforeAttempts, "Side-effect on attempts in \(tc.name)")
            XCTAssertEqual(harness.model.pendingMutations, beforePending, "Side-effect on pending mutations in \(tc.name)")
            XCTAssertEqual(harness.cache.writes, beforeCacheWrites, "Side-effect on cache writes in \(tc.name)")
        }
    }

    func testMultiCriteriaDerivesAttemptedAndCompletedStatus() throws {
        let harness = try makeHarness()
        let customItem = PracticeItem(
            id: "multi-criteria-test-item",
            kind: "General",
            topic: "System Design",
            week: 1,
            number: 1,
            title: "Multi Criteria Test",
            prompt: "Test Prompt",
            artifact: "Test Artifact",
            completionCriteria: [
                PracticeCompletionCriterion(id: "crit-a", requirement: "Req A", evidencePrompt: "Ev A"),
                PracticeCompletionCriterion(id: "crit-b", requirement: "Req B", evidencePrompt: "Ev B"),
                PracticeCompletionCriterion(id: "crit-c", requirement: "Req C", evidencePrompt: "Ev C")
            ]
        )

        // Inject into bundled practices in harness model for testing
        harness.model.practices = [customItem] + harness.model.practices

        // 1. Partial criteria -> derived .attempted
        let partialAttempt = try harness.model.submitPracticeAttempt(
            itemID: customItem.id,
            score: 2,
            notes: "Partial progress",
            artifact: "Partial artifact",
            satisfiedCriterionIDs: ["crit-b", "crit-a", "crit-b"] // duplicate and unordered
        )

        XCTAssertEqual(partialAttempt.status, .attempted)
        XCTAssertEqual(partialAttempt.submission?.satisfiedCriterionIDs, ["crit-a", "crit-b"]) // deduplicated & criterion order
        XCTAssertEqual(harness.model.practiceRecords[customItem.id]?.status, .attempted)
        XCTAssertEqual(harness.model.practiceRecords[customItem.id]?.attempts, 1)
        XCTAssertTrue(harness.model.hasSubmittedEvidence(for: customItem.id))

        // 2. All criteria -> derived .completed
        let allAttempt = try harness.model.submitPracticeAttempt(
            itemID: customItem.id,
            score: 4,
            notes: "Complete progress",
            artifact: "Complete artifact",
            satisfiedCriterionIDs: ["crit-c", "crit-a", "crit-b"]
        )

        XCTAssertEqual(allAttempt.status, .completed)
        XCTAssertEqual(allAttempt.submission?.satisfiedCriterionIDs, ["crit-a", "crit-b", "crit-c"])
        XCTAssertEqual(harness.model.practiceRecords[customItem.id]?.status, .completed)
        XCTAssertEqual(harness.model.practiceRecords[customItem.id]?.attempts, 2)
    }

    func testRepeatedSubmissionsAndImmutableSnapshots() throws {
        let harness = try makeHarness()
        let practice = try XCTUnwrap(harness.model.practices.first { $0.id == "general-1.1" })

        let attempt1 = try harness.model.submitPracticeAttempt(
            itemID: practice.id,
            score: 3,
            notes: "First submission",
            artifact: "Artifact v1",
            satisfiedCriterionIDs: practice.completionCriteria.map(\.id)
        )

        let attempt2 = try harness.model.submitPracticeAttempt(
            itemID: practice.id,
            score: 4,
            notes: "Second submission",
            artifact: "Artifact v2",
            satisfiedCriterionIDs: practice.completionCriteria.map(\.id)
        )

        XCTAssertNotEqual(attempt1.id, attempt2.id)
        let attempts = try XCTUnwrap(harness.model.practiceAttempts[practice.id])
        XCTAssertEqual(attempts.count, 2)

        // Verify snapshot 1 remains immutable
        XCTAssertEqual(attempts[0].id, attempt1.id)
        XCTAssertEqual(attempts[0].notes, "First submission")
        XCTAssertEqual(attempts[0].submission?.artifact, "Artifact v1")
        XCTAssertEqual(attempts[0].score, 3)

        // Verify snapshot 2
        XCTAssertEqual(attempts[1].id, attempt2.id)
        XCTAssertEqual(attempts[1].notes, "Second submission")
        XCTAssertEqual(attempts[1].submission?.artifact, "Artifact v2")
        XCTAssertEqual(attempts[1].score, 4)

        // Total attempts is 2
        XCTAssertEqual(harness.model.practiceRecords[practice.id]?.attempts, 2)

        // Modifying draft afterwards does not change past attempts or attempt count
        harness.model.savePracticeDraft(
            itemID: practice.id,
            status: .completed,
            score: 4,
            notes: "Draft update",
            artifact: "Draft artifact",
            satisfiedCriterionIDs: []
        )
        XCTAssertEqual(harness.model.practiceRecords[practice.id]?.attempts, 2)
        XCTAssertEqual(harness.model.practiceAttempts[practice.id]?.count, 2)
        XCTAssertEqual(harness.model.practiceAttempts[practice.id]?[0].notes, "First submission")
    }

    func testExactTwoPendingEnvelopesAtomicallyPersisted() throws {
        let harness = try makeHarness()
        let practice = try XCTUnwrap(harness.model.practices.first { $0.id == "general-1.1" })

        XCTAssertEqual(harness.model.pendingMutationCount, 0)
        let beforeWrites = harness.cache.writes

        let attempt = try harness.model.submitPracticeAttempt(
            itemID: practice.id,
            score: 4,
            notes: "Notes",
            artifact: "Artifact",
            satisfiedCriterionIDs: practice.completionCriteria.map(\.id)
        )

        XCTAssertEqual(harness.model.pendingMutationCount, 2)
        XCTAssertEqual(harness.cache.writes, beforeWrites + 1) // Persisted cache exactly once

        let recordKey = SyncKey(collection: .practice, recordID: practice.id)
        let attemptKey = SyncKey(collection: .practiceAttempts, recordID: attempt.id)
        XCTAssertNotNil(harness.model.pendingMutations[recordKey])
        XCTAssertNotNil(harness.model.pendingMutations[attemptKey])

        let cachedState = try decodeCache(harness.cache)
        XCTAssertEqual(cachedState.pendingMutations.count, 2)
        XCTAssertTrue(cachedState.pendingMutations.contains(where: { $0.key == recordKey }))
        XCTAssertTrue(cachedState.pendingMutations.contains(where: { $0.key == attemptKey }))
    }

    func testLegacyCacheLockedAndEvidenceCacheUnlocked() throws {
        let cache = MemoryStateCache()
        let practiceID = "general-1.1"
        let now = Date(timeIntervalSince1970: 500)

        // 1. Legacy practice record and legacy attempt (submission == nil)
        let legacyRecord = PracticeRecord(
            practiceID: practiceID,
            status: .completed,
            score: 4,
            notes: "Legacy notes",
            attempts: 3,
            legacyAttemptBaseline: 3,
            updatedAt: now
        )
        let legacyAttempt = PracticeAttempt(
            id: "legacy-att-1",
            practiceID: practiceID,
            status: .completed,
            score: 4,
            notes: "Legacy notes",
            submission: nil,
            completedAt: now,
            updatedAt: now
        )
        let legacyCached = CachedState(
            reviews: [:], flashcardWork: [:], practice: [practiceID: legacyRecord],
            practiceAttempts: [practiceID: [legacyAttempt]], profile: Defaults.profile,
            stories: [], companies: [], contacts: [], applications: [], pendingMutations: []
        )
        cache.storage["staff-deck-native-cache-v1"] = try SyncCoding.encoder.encode(legacyCached)

        let legacyHarness = try makeHarness(cache: cache)
        XCTAssertFalse(legacyHarness.model.hasSubmittedEvidence(for: practiceID), "Legacy attempt without submission should remain locked")
        XCTAssertEqual(legacyHarness.model.practiceRecords[practiceID]?.attempts, 3)
        XCTAssertEqual(legacyHarness.model.practiceRecords[practiceID]?.legacyAttemptBaseline, 3)

        // 2. Evidence-bearing attempt unlocks reveal
        let evidenceAttempt = PracticeAttempt(
            id: "evidence-att-2",
            practiceID: practiceID,
            status: .completed,
            score: 4,
            notes: "Modern notes",
            submission: PracticeSubmissionEvidence(artifact: "proof code", satisfiedCriterionIDs: ["legacy-completion"]),
            completedAt: now,
            updatedAt: now
        )
        let modernCached = CachedState(
            reviews: [:], flashcardWork: [:], practice: [practiceID: legacyRecord],
            practiceAttempts: [practiceID: [legacyAttempt, evidenceAttempt]], profile: Defaults.profile,
            stories: [], companies: [], contacts: [], applications: [], pendingMutations: []
        )
        cache.storage["staff-deck-native-cache-v1"] = try SyncCoding.encoder.encode(modernCached)

        let modernHarness = try makeHarness(cache: cache)
        XCTAssertTrue(modernHarness.model.hasSubmittedEvidence(for: practiceID), "Modern attempt with submission should be unlocked")
        // Normalization should count baseline (3) + 1 valid evidence attempt = 4
        XCTAssertEqual(modernHarness.model.practiceRecords[practiceID]?.attempts, 4)
        XCTAssertEqual(modernHarness.model.practiceRecords[practiceID]?.legacyAttemptBaseline, 3)

        // 3. Historical criterion ID not in current item still unlocks
        let historicalAttempt = PracticeAttempt(
            id: "hist-att-3",
            practiceID: practiceID,
            status: .completed,
            score: 4,
            notes: "Old criteria notes",
            submission: PracticeSubmissionEvidence(artifact: "historical code", satisfiedCriterionIDs: ["historical-old-crit-id"]),
            completedAt: now,
            updatedAt: now
        )
        let histCached = CachedState(
            reviews: [:], flashcardWork: [:], practice: [practiceID: legacyRecord],
            practiceAttempts: [practiceID: [historicalAttempt]], profile: Defaults.profile,
            stories: [], companies: [], contacts: [], applications: [], pendingMutations: []
        )
        cache.storage["staff-deck-native-cache-v1"] = try SyncCoding.encoder.encode(histCached)
        let histHarness = try makeHarness(cache: cache)
        XCTAssertTrue(histHarness.model.hasSubmittedEvidence(for: practiceID), "Historical valid submission should not relock on criteria changes")
    }

    func testRemoteArrivalOrderingAndNormalizationConvergence() async throws {
        let practiceID = "general-1.1"
        let now = Date(timeIntervalSince1970: 600)
        let record = PracticeRecord(
            practiceID: practiceID, status: .attempted, score: 3, notes: "Rec", attempts: 1,
            legacyAttemptBaseline: 1, updatedAt: now
        )
        let attempt1 = PracticeAttempt(
            id: "att-order-1", practiceID: practiceID, status: .attempted, score: 3, notes: "A1",
            submission: PracticeSubmissionEvidence(artifact: "art-1", satisfiedCriterionIDs: ["legacy-completion"]),
            completedAt: now, updatedAt: now
        )
        let attempt2 = PracticeAttempt(
            id: "att-order-2", practiceID: practiceID, status: .completed, score: 4, notes: "A2",
            submission: PracticeSubmissionEvidence(artifact: "art-2", satisfiedCriterionIDs: ["legacy-completion"]),
            completedAt: now.addingTimeInterval(10), updatedAt: now.addingTimeInterval(10)
        )

        let recordEnv = try SyncEnvelope.encode(record, collection: .practice, recordID: practiceID, updatedAtMilliseconds: 600_000)
        let att1Env = try SyncEnvelope.encode(attempt1, collection: .practiceAttempts, recordID: attempt1.id, updatedAtMilliseconds: 600_000)
        let att2Env = try SyncEnvelope.encode(attempt2, collection: .practiceAttempts, recordID: attempt2.id, updatedAtMilliseconds: 610_000)

        // Order A: record first, then attempts
        let harnessA = try makeHarness()
        try harnessA.model.applyRemote(recordEnv)
        XCTAssertEqual(harnessA.model.practiceRecords[practiceID]?.attempts, 1)
        try harnessA.model.applyRemote(att1Env)
        XCTAssertEqual(harnessA.model.practiceRecords[practiceID]?.attempts, 2)
        try harnessA.model.applyRemote(att2Env)
        XCTAssertEqual(harnessA.model.practiceRecords[practiceID]?.attempts, 3)
        XCTAssertEqual(harnessA.model.pendingMutationCount, 0, "Normalization must never enqueue mutations")

        // Order B: attempts first, then record
        let harnessB = try makeHarness()
        try harnessB.model.applyRemote(att1Env)
        try harnessB.model.applyRemote(att2Env)
        XCTAssertNil(harnessB.model.practiceRecords[practiceID])
        try harnessB.model.applyRemote(recordEnv)
        XCTAssertEqual(harnessB.model.practiceRecords[practiceID]?.attempts, 3)
        XCTAssertEqual(harnessB.model.pendingMutationCount, 0)

        // Full reconciliation convergence
        let harnessC = try makeHarness()
        let remoteSnapshot = RemoteSnapshot(rows: try Dictionary(grouping: baselineRows() + [recordEnv, att1Env, att2Env], by: \.collection))
        try harnessC.model.reconcileAll(remoteSnapshot)
        XCTAssertEqual(harnessC.model.practiceRecords[practiceID]?.attempts, 3)
        XCTAssertEqual(harnessC.model.pendingMutationCount, 0)
    }

    func testDuplicateUUIDReplacementInPracticeAttempts() throws {
        let harness = try makeHarness()
        let practiceID = "general-1.1"
        let now = Date(timeIntervalSince1970: 700)
        let att = PracticeAttempt(
            id: "uuid-duplicate-1", practiceID: practiceID, status: .attempted, score: 2, notes: "First version",
            submission: PracticeSubmissionEvidence(artifact: "art", satisfiedCriterionIDs: ["legacy-completion"]),
            completedAt: now, updatedAt: now
        )
        let updatedAtt = PracticeAttempt(
            id: "uuid-duplicate-1", practiceID: practiceID, status: .completed, score: 4, notes: "Updated version",
            submission: PracticeSubmissionEvidence(artifact: "art updated", satisfiedCriterionIDs: ["legacy-completion"]),
            completedAt: now, updatedAt: now.addingTimeInterval(5)
        )

        let env1 = try SyncEnvelope.encode(att, collection: .practiceAttempts, recordID: att.id, updatedAtMilliseconds: 700_000)
        let env2 = try SyncEnvelope.encode(updatedAtt, collection: .practiceAttempts, recordID: att.id, updatedAtMilliseconds: 705_000)

        try harness.model.applyRemote(env1)
        XCTAssertEqual(harness.model.practiceAttempts[practiceID]?.count, 1)
        XCTAssertEqual(harness.model.practiceAttempts[practiceID]?.first?.notes, "First version")

        try harness.model.applyRemote(env2)
        XCTAssertEqual(harness.model.practiceAttempts[practiceID]?.count, 1, "Duplicate UUID must replace rather than duplicate")
        XCTAssertEqual(harness.model.practiceAttempts[practiceID]?.first?.notes, "Updated version")
        XCTAssertEqual(harness.model.practiceAttempts[practiceID]?.first?.score, 4)
    }

    func testSubmissionFailedFlushRetainsBothEnvelopesAndRestartFlushes() async throws {
        let cache = MemoryStateCache()
        let offlineHarness = try makeHarness(cache: cache, credential: credentials)
        await offlineHarness.store.failNextUpserts(3)
        let practice = try XCTUnwrap(offlineHarness.model.practices.first { $0.id == "general-1.1" })

        try offlineHarness.model.submitPracticeAttempt(
            itemID: practice.id,
            score: 4,
            notes: "Offline submit",
            artifact: "Offline artifact",
            satisfiedCriterionIDs: practice.completionCriteria.map(\.id)
        )

        XCTAssertEqual(offlineHarness.model.pendingMutationCount, 2)
        await offlineHarness.model.syncNow()
        XCTAssertEqual(offlineHarness.model.pendingMutationCount, 2)
        guard case .offline = offlineHarness.model.syncState else { return XCTFail("Expected offline state") }

        // Restarting with the cache restores both pending mutations
        let restartedHarness = try makeHarness(cache: cache, credential: credentials)
        XCTAssertEqual(restartedHarness.model.pendingMutationCount, 2)
        await restartedHarness.model.syncNow()
        XCTAssertEqual(restartedHarness.model.pendingMutationCount, 0)
        let calls = await restartedHarness.store.calls()
        XCTAssertEqual(calls.filter { $0.collection == .practice || $0.collection == .practiceAttempts }.count, 2)
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
            dateSource: clock, calendar: Calendar(identifier: .gregorian), retrySleeper: sleeper
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
