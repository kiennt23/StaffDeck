import XCTest
@testable import StaffDeck

@MainActor
final class AppModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "staff-deck-native-cache-v1")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "staff-deck-native-cache-v1")
        super.tearDown()
    }

    func testGoodRatingSchedulesTwoDaysAndIncrementsReview() {
        let model = AppModel()
        let now = Date(timeIntervalSince1970: 2_000_000)

        model.rate(cardID: 42, rating: .good, now: now)

        let record = try! XCTUnwrap(model.reviews[42])
        XCTAssertEqual(record.intervalDays, 2)
        XCTAssertEqual(record.reviews, 1)
        XCTAssertEqual(record.rating, .good)
        XCTAssertEqual(record.dueAt.timeIntervalSince(now), 2 * 86_400, accuracy: 1)
    }

    func testAgainRatingSchedulesTenMinutes() {
        let model = AppModel()
        let now = Date(timeIntervalSince1970: 2_000_000)

        model.rate(cardID: 7, rating: .again, now: now)

        let record = try! XCTUnwrap(model.reviews[7])
        XCTAssertEqual(record.intervalDays, 0)
        XCTAssertEqual(record.dueAt.timeIntervalSince(now), 600, accuracy: 0.01)
    }

    func testInterviewTopicsFollowTheLearningPath() {
        XCTAssertEqual(
            InterviewTopic.allCases,
            [
                .javaFundamentals,
                .javaAPI,
                .jvmConcurrency,
                .spring,
                .dsa,
                .databases,
                .systemDesign,
                .security,
                .cloudPlatform,
                .reliability,
                .leadership,
                .staffScenarios,
                .goFundamentals,
                .goServices,
                .goConcurrency,
                .goArchitecture,
            ]
        )
    }

    func testGoTrackShowsGoFoundationsBeforeSharedDSA() {
        XCTAssertEqual(
            InterviewTopic.topics(in: .foundations, track: .go),
            [.goFundamentals, .goServices, .goConcurrency, .goArchitecture, .dsa]
        )
    }

    func testGoFundamentalsHaveFilterableSubtopics() {
        let model = AppModel()
        let goFundamentals = model.flashcards.filter { $0.topic == InterviewTopic.goFundamentals.rawValue }

        XCTAssertEqual(goFundamentals.count, 44)
        XCTAssertTrue(goFundamentals.allSatisfy { $0.subtopic != nil })
        XCTAssertEqual(
            Set(goFundamentals.compactMap(\.subtopic)),
            Set(GoFundamentalTopic.allCases.map(\.rawValue))
        )
    }

    func testConcurrencyCardsCoverEachFilterableSubtopic() {
        assertSubtopicCoverage(topics: [.jvmConcurrency, .goConcurrency], ConcurrencySubtopic.self)
    }

    func testServiceCardsCoverEachFilterableSubtopic() {
        assertSubtopicCoverage(topics: [.javaAPI, .goServices], ServiceSubtopic.self)
    }

    func testDatabaseCardsCoverEachFilterableSubtopic() {
        assertSubtopicCoverage(topics: [.databases], DatabaseSubtopic.self)
    }

    func testSecurityCardsCoverEachFilterableSubtopic() {
        assertSubtopicCoverage(topics: [.security], SecuritySubtopic.self)
    }

    func testReliabilityCardsCoverEachFilterableSubtopic() {
        assertSubtopicCoverage(topics: [.reliability], ReliabilitySubtopic.self)
    }

    func testPlatformCardsCoverEachFilterableSubtopic() {
        assertSubtopicCoverage(topics: [.cloudPlatform], PlatformSubtopic.self)
    }

    private func assertSubtopicCoverage<Subtopic: CaseIterable & RawRepresentable>(
        topics: [InterviewTopic],
        _ type: Subtopic.Type,
        file: StaticString = #filePath,
        line: UInt = #line
    ) where Subtopic.RawValue == String {
        let model = AppModel()
        for topic in topics {
            let subtopics = model.flashcards
                .filter { $0.topic == topic.rawValue }
                .compactMap(\.subtopic)
            XCTAssertEqual(
                Set(subtopics),
                Set(Subtopic.allCases.map(\.rawValue)),
                "\(topic.rawValue) cards should cover every filterable subtopic",
                file: file,
                line: line
            )
        }
    }

    func testEverySubtopicBelongsToItsTopicsFilterVocabulary() {
        let vocabularies: [InterviewTopic: Set<String>] = [
            .javaFundamentals: Set(FundamentalTopic.allCases.map(\.rawValue)),
            .goFundamentals: Set(GoFundamentalTopic.allCases.map(\.rawValue)),
            .jvmConcurrency: Set(ConcurrencySubtopic.allCases.map(\.rawValue)),
            .goConcurrency: Set(ConcurrencySubtopic.allCases.map(\.rawValue)),
            .javaAPI: Set(ServiceSubtopic.allCases.map(\.rawValue)),
            .goServices: Set(ServiceSubtopic.allCases.map(\.rawValue)),
            .databases: Set(DatabaseSubtopic.allCases.map(\.rawValue)),
            .security: Set(SecuritySubtopic.allCases.map(\.rawValue)),
            .reliability: Set(ReliabilitySubtopic.allCases.map(\.rawValue)),
            .cloudPlatform: Set(PlatformSubtopic.allCases.map(\.rawValue)),
        ]
        let model = AppModel()

        for card in model.flashcards {
            guard let subtopic = card.subtopic else { continue }
            let topic = try! XCTUnwrap(InterviewTopic(rawValue: card.topic))
            let vocabulary = try! XCTUnwrap(
                vocabularies[topic],
                "Card \(card.id) declares subtopic \"\(subtopic)\" on unfilterable topic \(card.topic)"
            )
            XCTAssertTrue(
                vocabulary.contains(subtopic),
                "Card \(card.id) declares unknown subtopic \"\(subtopic)\" for topic \(card.topic)"
            )
        }
    }

    func testEveryFlashcardTopicHasASidebarDestination() {
        let model = AppModel()

        XCTAssertEqual(
            Set(model.flashcards.map(\.topic)),
            Set(InterviewTopic.allCases.map(\.rawValue))
        )
    }

    func testJavaFundamentalsCoverageAndCardIDs() {
        let model = AppModel()
        let fundamentals = model.flashcards.filter {
            $0.topic == InterviewTopic.javaFundamentals.rawValue
        }

        XCTAssertEqual(model.flashcards.count, 300)
        XCTAssertEqual(Set(model.flashcards.map(\.id)).count, 300)
        XCTAssertEqual(model.flashcards.map(\.id).min(), 1)
        XCTAssertEqual(model.flashcards.map(\.id).max(), 300)
        XCTAssertEqual(fundamentals.count, 44)
        XCTAssertTrue(fundamentals.allSatisfy { $0.followUps.count == 3 })
        XCTAssertTrue(fundamentals.allSatisfy { $0.subtopic != nil })
        XCTAssertEqual(
            Set(fundamentals.compactMap(\.subtopic)),
            Set(FundamentalTopic.allCases.map(\.rawValue))
        )
        XCTAssertTrue(
            model.flashcards
                .filter { $0.topic != InterviewTopic.javaFundamentals.rawValue }
                .allSatisfy { card in
                    card.subtopic.map { FundamentalTopic(rawValue: $0) == nil } ?? true
                }
        )
    }

    func testEveryGeneralPracticeHasAStaffLevelRubric() {
        let model = AppModel()
        let generalPractices = model.practices.filter { $0.kind == "General" }

        XCTAssertEqual(model.practices.count, 240)
        XCTAssertEqual(generalPractices.count, 136)
        for practice in generalPractices {
            XCTAssertNotNil(practice.rubricKind, "Practice \(practice.id) has nil rubricKind")
            XCTAssertNotNil(practice.generalRubric, "Practice \(practice.id) has nil generalRubric")
            XCTAssertFalse(practice.competencyTopics.isEmpty, "Practice \(practice.id) has empty competencyTopics")
        }
        for practice in model.practices.filter({ $0.kind == "DSA" }) {
            XCTAssertNil(practice.generalRubric, "DSA practice \(practice.id) has non-nil generalRubric")
            XCTAssertNil(practice.rubricKind, "DSA practice \(practice.id) has non-nil rubricKind")
            XCTAssertEqual(practice.competencyTopics, [.dsa], "DSA practice \(practice.id) competencyTopics != [.dsa]")
        }
    }
    func testGoPracticesHaveTheSameCoachingFeaturesAsGeneralPractices() {
        let model = AppModel()
        let goPractices = model.practices.filter { $0.contentTrack == .go }

        XCTAssertEqual(goPractices.count, 22)
        XCTAssertTrue(goPractices.allSatisfy { practice in
            practice.isAvailable(in: .go)
                && !practice.isAvailable(in: .java)
                && practice.generalRubric != nil
                && practice.followUps.count == 3
                && !practice.completion.isEmpty
                && practice.modelAnswer?.isEmpty == false
        })
    }

    func testTestingAndDependencyContentHasJavaGoParity() {
        let model = AppModel()
        let testingCards = model.flashcards.filter { (196...201).contains($0.id) }

        XCTAssertEqual(testingCards.filter { $0.contentTrack == .java }.count, 3)
        XCTAssertEqual(testingCards.filter { $0.contentTrack == .go }.count, 3)

        let javaPractice = try! XCTUnwrap(model.practices.first { $0.id == "java-testing-dependencies" })
        let goPractice = try! XCTUnwrap(model.practices.first { $0.id == "go-testing-dependencies" })
        let sharedPractice = try! XCTUnwrap(model.practices.first { $0.id == "staff-quality-gates" })

        XCTAssertTrue(javaPractice.isAvailable(in: .java))
        XCTAssertFalse(javaPractice.isAvailable(in: .go))
        XCTAssertTrue(goPractice.isAvailable(in: .go))
        XCTAssertFalse(goPractice.isAvailable(in: .java))
        XCTAssertTrue(sharedPractice.isAvailable(in: .java))
        XCTAssertTrue(sharedPractice.isAvailable(in: .go))
        XCTAssertTrue([javaPractice, goPractice, sharedPractice].allSatisfy {
            $0.generalRubric != nil && $0.followUps.count == 3 && !$0.completion.isEmpty
        })
    }

    func testLegacyPracticeItemDecodesCompletionIntoLegacyCriterion() throws {
        let json = """
        {
            "id": "legacy-item-1",
            "kind": "General",
            "topic": "JVM & Concurrency",
            "week": 1,
            "number": 1,
            "title": "Legacy Practice Title",
            "prompt": "Legacy prompt text",
            "artifact": "Legacy artifact description",
            "followUps": ["Follow up 1"],
            "completion": "State the invariant and failure modes."
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(PracticeItem.self, from: json)
        XCTAssertEqual(item.id, "legacy-item-1")
        XCTAssertEqual(item.completion, "State the invariant and failure modes.")
        XCTAssertEqual(item.completionCriteria.count, 1)
        let criterion = try XCTUnwrap(item.completionCriteria.first)
        XCTAssertEqual(criterion.id, "legacy-completion")
        XCTAssertEqual(criterion.requirement, "State the invariant and failure modes.")
        XCTAssertEqual(criterion.evidencePrompt, "Legacy artifact description")
    }

    func testNewPracticeItemDecodesExplicitCompletionCriteria() throws {
        let json = """
        {
            "id": "structured-item-1",
            "kind": "General",
            "topic": "System Design",
            "week": 2,
            "number": 3,
            "title": "Structured Criteria Practice",
            "prompt": "Design an outbox worker",
            "artifact": "Design doc and sequence diagram",
            "followUps": [],
            "completion": "Legacy completion summary",
            "completionCriteria": [
                {
                    "id": "invariant-definition",
                    "requirement": "Define exactly-once relay invariant",
                    "evidencePrompt": "Explain outbox table deduplication"
                },
                {
                    "id": "backoff-policy",
                    "requirement": "Describe exponential retry backoff",
                    "evidencePrompt": "Provide jitter formula and limits"
                }
            ]
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(PracticeItem.self, from: json)
        XCTAssertEqual(item.completionCriteria.count, 2)
        XCTAssertEqual(item.completionCriteria[0].id, "invariant-definition")
        XCTAssertEqual(item.completionCriteria[0].requirement, "Define exactly-once relay invariant")
        XCTAssertEqual(item.completionCriteria[0].evidencePrompt, "Explain outbox table deduplication")
        XCTAssertEqual(item.completionCriteria[1].id, "backoff-policy")
        XCTAssertEqual(item.completionCriteria[1].requirement, "Describe exponential retry backoff")
        XCTAssertEqual(item.completionCriteria[1].evidencePrompt, "Provide jitter formula and limits")

        let reencoded = try JSONEncoder().encode(item)
        let decodedAgain = try JSONDecoder().decode(PracticeItem.self, from: reencoded)
        XCTAssertEqual(decodedAgain.completion, "Legacy completion summary")
        XCTAssertEqual(decodedAgain.completionCriteria, item.completionCriteria)
    }

    func testLegacyPracticeItemWithEmptyCompletionHasEmptyCriteria() throws {
        let json = """
        {
            "id": "empty-completion-item",
            "kind": "General",
            "topic": "Databases",
            "week": 1,
            "number": 1,
            "title": "Empty Completion",
            "prompt": "Prompt",
            "artifact": "Artifact",
            "followUps": [],
            "completion": "   "
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(PracticeItem.self, from: json)
        XCTAssertTrue(item.completionCriteria.isEmpty)
    }

    func testLegacyPracticeRecordDecodesDraftFieldsAndBaselineDefaulting() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let json = """
        {
            "practiceID": "general-1.1",
            "status": "attempted",
            "score": 3,
            "notes": "Good progress",
            "attempts": 4,
            "updatedAt": 1700000000000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let record = try decoder.decode(PracticeRecord.self, from: json)

        XCTAssertEqual(record.practiceID, "general-1.1")
        XCTAssertEqual(record.status, .attempted)
        XCTAssertEqual(record.score, 3)
        XCTAssertEqual(record.notes, "Good progress")
        XCTAssertEqual(record.attempts, 4)
        XCTAssertEqual(record.draftArtifact, "")
        XCTAssertEqual(record.draftSatisfiedCriterionIDs, [])
        XCTAssertEqual(record.legacyAttemptBaseline, 4)
        XCTAssertNil(record.nextReviewAt)
        XCTAssertEqual(record.updatedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    func testNewPracticeRecordRoundTripWithDraftFields() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let record = PracticeRecord(
            practiceID: "general-1.2",
            status: .completed,
            score: 4,
            notes: "Ready for review",
            attempts: 5,
            draftArtifact: "Drafting code snippet...",
            draftSatisfiedCriterionIDs: ["crit-1", "crit-2"],
            legacyAttemptBaseline: 3,
            nextReviewAt: now.addingTimeInterval(86400),
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let data = try encoder.encode(record)
        let decoded = try decoder.decode(PracticeRecord.self, from: data)

        XCTAssertEqual(decoded.practiceID, "general-1.2")
        XCTAssertEqual(decoded.status, .completed)
        XCTAssertEqual(decoded.score, 4)
        XCTAssertEqual(decoded.notes, "Ready for review")
        XCTAssertEqual(decoded.attempts, 5)
        XCTAssertEqual(decoded.draftArtifact, "Drafting code snippet...")
        XCTAssertEqual(decoded.draftSatisfiedCriterionIDs, ["crit-1", "crit-2"])
        XCTAssertEqual(decoded.legacyAttemptBaseline, 3)
        XCTAssertEqual(decoded.nextReviewAt?.timeIntervalSince1970, now.addingTimeInterval(86400).timeIntervalSince1970)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    func testLegacyPracticeAttemptDecodesNilSubmission() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let json = """
        {
            "id": "attempt-legacy-1",
            "practiceID": "general-1.1",
            "status": "attempted",
            "score": 2,
            "notes": "First attempt notes",
            "completedAt": 1700000000000,
            "updatedAt": 1700000000000
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let attempt = try decoder.decode(PracticeAttempt.self, from: json)

        XCTAssertEqual(attempt.id, "attempt-legacy-1")
        XCTAssertEqual(attempt.practiceID, "general-1.1")
        XCTAssertEqual(attempt.status, .attempted)
        XCTAssertEqual(attempt.score, 2)
        XCTAssertEqual(attempt.notes, "First attempt notes")
        XCTAssertNil(attempt.submission)
        XCTAssertEqual(attempt.completedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    func testNewPracticeAttemptRoundTripWithSubmission() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let submission = PracticeSubmissionEvidence(
            artifact: "Final solution implementation",
            satisfiedCriterionIDs: ["crit-1", "crit-2"]
        )
        let attempt = PracticeAttempt(
            id: "attempt-submission-1",
            practiceID: "general-1.1",
            status: .completed,
            score: 4,
            notes: "Passed all criteria",
            submission: submission,
            completedAt: now,
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let data = try encoder.encode(attempt)
        let decoded = try decoder.decode(PracticeAttempt.self, from: data)

        XCTAssertEqual(decoded.id, "attempt-submission-1")
        XCTAssertEqual(decoded.practiceID, "general-1.1")
        XCTAssertEqual(decoded.status, .completed)
        XCTAssertEqual(decoded.score, 4)
        XCTAssertEqual(decoded.notes, "Passed all criteria")
        let decodedSubmission = try XCTUnwrap(decoded.submission)
        XCTAssertEqual(decodedSubmission.artifact, "Final solution implementation")
        XCTAssertEqual(decodedSubmission.satisfiedCriterionIDs, ["crit-1", "crit-2"])
    }

    func testModelInitializersSensibleDefaults() {
        let now = Date()
        let record = PracticeRecord(
            practiceID: "test-rec",
            status: .notStarted,
            updatedAt: now
        )
        XCTAssertEqual(record.attempts, 0)
        XCTAssertEqual(record.draftArtifact, "")
        XCTAssertEqual(record.draftSatisfiedCriterionIDs, [])
        XCTAssertEqual(record.legacyAttemptBaseline, 0)
        XCTAssertNil(record.score)
        XCTAssertNil(record.nextReviewAt)
        XCTAssertEqual(record.notes, "")

        let attempt = PracticeAttempt(
            id: "test-att",
            practiceID: "test-rec",
            status: .notStarted,
            completedAt: now,
            updatedAt: now
        )
        XCTAssertNil(attempt.submission)
        XCTAssertNil(attempt.score)
        XCTAssertEqual(attempt.notes, "")
    }

    func testPracticeCriterionAndEvidenceConformToSendable() {
        assertSendable(PracticeCompletionCriterion.self)
        assertSendable(PracticeSubmissionEvidence.self)
    }

    private func assertSendable<T: Sendable>(_: T.Type) {}
}
