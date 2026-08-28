import Foundation

enum TopicMasteryStatus: String, CaseIterable, Identifiable, Equatable {
    case notAssessed = "Not assessed"
    case needsReview = "Needs review"
    case buildingEvidence = "Building evidence"
    case mastered = "Mastered"

    var id: String { rawValue }

    var statusTitle: String { rawValue }
}

struct TopicMastery: Identifiable, Equatable {
    let topic: InterviewTopic
    let reviewedCount: Int
    let totalCards: Int
    let weakCount: Int
    let practiceCount: Int
    let completedPracticeCount: Int
    let averagePracticeScore: Double?
    let status: TopicMasteryStatus

    var id: String { topic.rawValue }
}

struct MasteryMetrics: Equatable {
    let track: LanguageTrack
    let cardsReviewed: Int
    let totalAvailableCards: Int
    let retentionRate: Double?
    let averagePracticeScore: Double?
    let completedPracticesCount: Int
    let totalAvailablePractices: Int
    let topicMasteries: [TopicMastery]

    init(
        track: LanguageTrack,
        flashcards: [Flashcard],
        practices: [PracticeItem],
        reviews: [Int: ReviewRecord],
        practiceRecords: [String: PracticeRecord]
    ) {
        self.track = track

        let availableCards = flashcards.filter { $0.isAvailable(in: track) }
        let availableCardIDs = Set(availableCards.map(\.id))
        self.totalAvailableCards = availableCards.count

        let activeReviews = reviews.values.filter { availableCardIDs.contains($0.cardID) }
        self.cardsReviewed = activeReviews.count

        let strongReviews = activeReviews.filter { $0.rating == .good || $0.rating == .easy }.count
        self.retentionRate = activeReviews.isEmpty
            ? nil
            : Double(strongReviews) / Double(activeReviews.count)

        let availablePractices = practices.filter { $0.isAvailable(in: track) }
        let availablePracticeIDs = Set(availablePractices.map(\.id))
        self.totalAvailablePractices = availablePractices.count

        let scoredRecords = practiceRecords.values.compactMap { record -> Int? in
            guard availablePracticeIDs.contains(record.practiceID) else { return nil }
            return record.score
        }
        self.averagePracticeScore = scoredRecords.isEmpty
            ? nil
            : Double(scoredRecords.reduce(0, +)) / Double(scoredRecords.count)

        self.completedPracticesCount = practiceRecords.values.filter {
            availablePracticeIDs.contains($0.practiceID) && $0.status == .completed
        }.count

        let topics = InterviewTopic.topics(for: track)
        self.topicMasteries = topics.map { topic in
            let topicCards = availableCards.filter { $0.topic == topic.rawValue }
            let topicCardIDs = Set(topicCards.map(\.id))
            let topicReviews = reviews.values.filter { topicCardIDs.contains($0.cardID) }
            let weakCount = topicReviews.filter { $0.rating == .again || $0.rating == .hard }.count

            let topicPractices = availablePractices.filter { practice in
                practice.competencyTopics.contains(topic) || practice.topic.localizedCaseInsensitiveContains(topic.rawValue)
            }
            let topicPracticeIDs = Set(topicPractices.map(\.id))
            let topicPracticeRecords = practiceRecords.values.filter { topicPracticeIDs.contains($0.practiceID) }
            let topicScores = topicPracticeRecords.compactMap(\.score)
            let avgScore = topicScores.isEmpty ? nil : Double(topicScores.reduce(0, +)) / Double(topicScores.count)
            let completedPractices = topicPracticeRecords.filter { $0.status == .completed }.count

            let status: TopicMasteryStatus
            if topicReviews.isEmpty && topicPracticeRecords.isEmpty {
                status = .notAssessed
            } else if weakCount > 0 || (avgScore != nil && avgScore! < 2.5) {
                status = .needsReview
            } else if topicReviews.count >= topicCards.count / 2 && (avgScore == nil || avgScore! >= 3.0) {
                status = .mastered
            } else {
                status = .buildingEvidence
            }

            return TopicMastery(
                topic: topic,
                reviewedCount: topicReviews.count,
                totalCards: topicCards.count,
                weakCount: weakCount,
                practiceCount: topicPractices.count,
                completedPracticeCount: completedPractices,
                averagePracticeScore: avgScore,
                status: status
            )
        }
    }
}
