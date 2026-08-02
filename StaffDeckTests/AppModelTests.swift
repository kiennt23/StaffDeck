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
            ]
        )
    }

    func testEveryFlashcardTopicHasASidebarDestination() {
        let model = AppModel()

        XCTAssertEqual(
            Set(model.flashcards.map(\.topic)),
            Set(InterviewTopic.allCases.map(\.rawValue))
        )
    }
}
