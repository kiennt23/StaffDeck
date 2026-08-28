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
}
