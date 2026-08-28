import XCTest
@testable import StaffDeck

@MainActor
final class ProgressMetricsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "staff-deck-native-cache-v1")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "staff-deck-native-cache-v1")
        super.tearDown()
    }

    func testProgressTopicsFollowCanonicalTrackOrdering() {
        XCTAssertEqual(
            InterviewTopic.topics(for: .java),
            [
                .javaFundamentals, .javaAPI, .jvmConcurrency, .spring, .dsa,
                .databases, .systemDesign, .security, .cloudPlatform, .reliability,
                .leadership, .staffScenarios,
            ]
        )
        XCTAssertEqual(
            InterviewTopic.topics(for: .go),
            [
                .goFundamentals, .goServices, .goConcurrency, .goArchitecture, .dsa,
                .databases, .systemDesign, .security, .cloudPlatform, .reliability,
                .leadership, .staffScenarios,
            ]
        )
    }

    func testLearningProgressMetricsTrackScoping() {
        let model = AppModel()
        let now = Date()

        let javaCard = try! XCTUnwrap(model.flashcards.first { $0.isAvailable(in: .java) && !$0.isAvailable(in: .go) })
        let goCard = try! XCTUnwrap(model.flashcards.first { $0.isAvailable(in: .go) && !$0.isAvailable(in: .java) })
        let sharedCard = try! XCTUnwrap(model.flashcards.first { $0.isAvailable(in: .java) && $0.isAvailable(in: .go) })

        let javaPractice = try! XCTUnwrap(model.practices.first { $0.isAvailable(in: .java) && !$0.isAvailable(in: .go) })
        let goPractice = try! XCTUnwrap(model.practices.first { $0.isAvailable(in: .go) && !$0.isAvailable(in: .java) })
        let sharedPractice = try! XCTUnwrap(model.practices.first { $0.isAvailable(in: .java) && $0.isAvailable(in: .go) })
        let unscoredSharedPractice = try! XCTUnwrap(model.practices.first { $0.isAvailable(in: .java) && $0.isAvailable(in: .go) && $0.id != sharedPractice.id })

        model.rate(cardID: javaCard.id, rating: .good, now: now)
        model.rate(cardID: goCard.id, rating: .good, now: now)
        model.rate(cardID: sharedCard.id, rating: .good, now: now)
        model.rate(cardID: 999999, rating: .good, now: now)

        try! model.submitPracticeAttempt(
            itemID: javaPractice.id,
            score: 4,
            notes: "",
            artifact: "Java solution evidence",
            satisfiedCriterionIDs: javaPractice.completionCriteria.map(\.id)
        )
        try! model.submitPracticeAttempt(
            itemID: goPractice.id,
            score: 2,
            notes: "",
            artifact: "Go solution evidence",
            satisfiedCriterionIDs: goPractice.completionCriteria.map(\.id)
        )
        try! model.submitPracticeAttempt(
            itemID: sharedPractice.id,
            score: 3,
            notes: "",
            artifact: "Shared solution evidence",
            satisfiedCriterionIDs: sharedPractice.completionCriteria.map(\.id)
        )
        model.savePracticeDraft(
            itemID: unscoredSharedPractice.id,
            status: .attempted,
            score: nil,
            notes: ""
        )
        model.savePracticeDraft(
            itemID: "orphan-practice",
            status: .completed,
            score: 4,
            notes: ""
        )

        let javaMetrics = MasteryMetrics(
            track: .java,
            flashcards: model.flashcards,
            practices: model.practices,
            reviews: model.reviews,
            practiceRecords: model.practiceRecords
        )

        XCTAssertEqual(javaMetrics.cardsReviewed, 2)
        XCTAssertEqual(javaMetrics.averagePracticeScore, 3.5)
        XCTAssertEqual(javaMetrics.completedPracticesCount, 2)
        XCTAssertEqual(javaMetrics.retentionRate, 1.0)

        let goMetrics = MasteryMetrics(
            track: .go,
            flashcards: model.flashcards,
            practices: model.practices,
            reviews: model.reviews,
            practiceRecords: model.practiceRecords
        )

        XCTAssertEqual(goMetrics.cardsReviewed, 2)
        XCTAssertEqual(goMetrics.averagePracticeScore, 2.5)
        XCTAssertEqual(goMetrics.completedPracticesCount, 2)
        XCTAssertEqual(goMetrics.retentionRate, 1.0)
    }
}
