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
            SidebarDestination.topic(.javaFundamentals).resolved(for: .go),
            .topic(.goFundamentals)
        )
        XCTAssertEqual(
            SidebarDestination.topic(.goFundamentals).resolved(for: .java),
            .topic(.javaFundamentals)
        )
    }
}
