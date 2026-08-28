import XCTest
@testable import StaffDeck

final class NavigationSelectionTests: XCTestCase {
    func testWorkspaceDestinationsSurviveTrackChanges() {
        for section in WorkspaceSection.allCases {
            let destination = SidebarDestination.workspace(section)
            XCTAssertEqual(destination.resolved(for: .java), destination)
            XCTAssertEqual(destination.resolved(for: .go), destination)
        }
    }

    func testSharedTopicSurvivesTrackChanges() {
        let destination = SidebarDestination.topic(.dsa)
        XCTAssertEqual(destination.resolved(for: .java), destination)
        XCTAssertEqual(destination.resolved(for: .go), destination)
    }

    func testCompatibleTopicsRemainSelected() {
        XCTAssertEqual(
            SidebarDestination.topic(.javaAPI).resolved(for: .java),
            .topic(.javaAPI)
        )
        XCTAssertEqual(
            SidebarDestination.topic(.goServices).resolved(for: .go),
            .topic(.goServices)
        )
    }

    func testIncompatibleTopicsRedirectToTrackDefault() {
        XCTAssertEqual(
            SidebarDestination.topic(.javaFundamentals, targetCardID: 42).resolved(for: .go),
            .topic(.goFundamentals, targetCardID: nil)
        )
        XCTAssertEqual(
            SidebarDestination.topic(.goFundamentals, targetCardID: 210).resolved(for: .java),
            .topic(.javaFundamentals, targetCardID: nil)
        )
    }

    func testCompatibleTopicsPreserveTargetCardID() {
        XCTAssertEqual(
            SidebarDestination.topic(.javaAPI, targetCardID: 99).resolved(for: .java),
            .topic(.javaAPI, targetCardID: 99)
        )
        XCTAssertEqual(
            SidebarDestination.topic(.dsa, targetCardID: 15).resolved(for: .go),
            .topic(.dsa, targetCardID: 15)
        )
    }

    @MainActor
    func testTodayRecommendationsEvaluatesDueItemsAndTargets() {
        let model = AppModel()
        let recs = TodayRecommendations.evaluate(
            track: .go,
            flashcards: model.flashcards,
            practices: model.practices,
            reviews: [:],
            practiceRecords: [:],
            stories: model.stories,
            now: Date(timeIntervalSince1970: 100_000)
        )
        XCTAssertNotNil(recs.reviewCard)
        XCTAssertEqual(recs.reviewCard?.isAvailable(in: .go), true)
        XCTAssertNotNil(recs.practice)
        XCTAssertEqual(recs.practice?.isAvailable(in: .go), true)
        XCTAssertNotNil(recs.story)
    }
}
