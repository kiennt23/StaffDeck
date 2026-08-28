import Foundation

struct TodayRecommendations: Equatable {
    let reviewCard: Flashcard?
    let practice: PracticeItem?
    let story: StaffStory?
    let dueReviewCount: Int
    let duePracticeCount: Int
    let completedPracticeCount: Int
    let reviewReason: String
    let practiceReason: String

    static func evaluate(
        track: LanguageTrack,
        flashcards: [Flashcard],
        practices: [PracticeItem],
        reviews: [Int: ReviewRecord],
        practiceRecords: [String: PracticeRecord],
        stories: [StaffStory],
        now: Date
    ) -> TodayRecommendations {
        let availableCards = flashcards.filter { card in
            guard let topic = InterviewTopic(rawValue: card.topic) else { return false }
            guard topic.languageTrack == nil || topic.languageTrack == track else { return false }
            return card.isAvailable(in: track)
        }

        let dueCards = availableCards.filter { card in
            (reviews[card.id]?.dueAt ?? .distantPast) <= now
        }

        let weakTopicCounts: [InterviewTopic: Int] = Dictionary(
            grouping: reviews.values.filter { $0.rating == .again || $0.rating == .hard },
            by: { review in
                flashcards.first(where: { $0.id == review.cardID }).flatMap { InterviewTopic(rawValue: $0.topic) } ?? .javaFundamentals
            }
        ).reduce(into: [:]) { acc, entry in
            if entry.key.languageTrack == nil || entry.key.languageTrack == track {
                acc[entry.key] = entry.value.count
            }
        }

        func cardPriority(_ card: Flashcard) -> Int {
            let ratingPriority: Int
            switch reviews[card.id]?.rating {
            case .again?: ratingPriority = 3
            case .hard?: ratingPriority = 2
            default: ratingPriority = 0
            }
            let topic = InterviewTopic(rawValue: card.topic) ?? .javaFundamentals
            return ratingPriority + (weakTopicCounts[topic] ?? 0)
        }

        let sortedDueCards = dueCards.sorted { left, right in
            let leftP = cardPriority(left)
            let rightP = cardPriority(right)
            if leftP != rightP { return leftP > rightP }
            let leftDue = reviews[left.id]?.dueAt ?? .distantPast
            let rightDue = reviews[right.id]?.dueAt ?? .distantPast
            return leftDue == rightDue ? left.id < right.id : leftDue < rightDue
        }

        let selectedReviewCard = sortedDueCards.first

        // Practices
        let availablePractices = practices.filter { $0.isAvailable(in: track) }
        let dueReSolves = availablePractices.filter { practice in
            practiceRecords[practice.id]?.nextReviewAt.map { $0 <= now } == true
        }

        func practicePriority(_ practice: PracticeItem) -> Int {
            let scorePriority = max(0, 3 - (practiceRecords[practice.id]?.score ?? 4))
            let weakOverlap = practice.competencyTopics.reduce(0) { sum, topic in
                sum + (weakTopicCounts[topic] ?? 0)
            }
            return scorePriority + weakOverlap
        }

        func practiceSort(_ left: PracticeItem, _ right: PracticeItem) -> Bool {
            let leftP = practicePriority(left)
            let rightP = practicePriority(right)
            if leftP != rightP { return leftP > rightP }
            return left.week == right.week ? left.number < right.number : left.week < right.week
        }

        let selectedPractice: PracticeItem? = {
            if let due = dueReSolves.sorted(by: practiceSort).first {
                return due
            }
            let unstarted = availablePractices.filter { practiceRecords[$0.id] == nil }
            return unstarted.sorted(by: practiceSort).first
        }()

        let selectedStory = stories
            .filter { !$0.isDeleted }
            .sorted { $0.updatedAt < $1.updatedAt }
            .first

        let duePracticeCount = practiceRecords.values.filter {
            ($0.nextReviewAt ?? .distantFuture) <= now
        }.count

        let completedPracticeCount = practiceRecords.values.filter {
            $0.status == .completed
        }.count

        let reviewReason: String = {
            guard let card = selectedReviewCard else { return "No cards due for review." }
            return cardPriority(card) > 0
                ? "This due card targets a weak area. Say the answer before revealing it, then rate it honestly."
                : "Start with your oldest due card in \(card.topic). Say the answer before revealing it."
        }()

        let practiceReason: String = {
            guard let p = selectedPractice else { return "No practice drills available." }
            if practiceRecords[p.id]?.nextReviewAt != nil {
                return "This is due for a re-solve. Work from an empty editor, then compare your decisions with the prior attempt."
            }
            if practicePriority(p) > 0 {
                return "This exercise supports a weak area from your review history. Start a first attempt before reading any guide."
            }
            return "Start a first attempt and capture the evidence requested by the exercise before reading any guide."
        }()

        return TodayRecommendations(
            reviewCard: selectedReviewCard,
            practice: selectedPractice,
            story: selectedStory,
            dueReviewCount: dueCards.count,
            duePracticeCount: duePracticeCount,
            completedPracticeCount: completedPracticeCount,
            reviewReason: reviewReason,
            practiceReason: practiceReason
        )
    }
}
