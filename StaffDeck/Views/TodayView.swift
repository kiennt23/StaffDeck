import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    let track: LanguageTrack
    let openTopic: (InterviewTopic) -> Void
    let openPractice: () -> Void
    let openCareer: () -> Void

    private var reviewCard: Flashcard? {
        let now = Date()
        return model.flashcards
            .filter {
                (topic(for: $0).languageTrack == nil || topic(for: $0).languageTrack == track)
                    && $0.isAvailable(in: track)
                    && (model.reviews[$0.id]?.dueAt ?? .distantPast) <= now
            }
            .sorted { left, right in
                let leftPriority = reviewPriority(for: left)
                let rightPriority = reviewPriority(for: right)
                if leftPriority != rightPriority { return leftPriority > rightPriority }
                let leftDue = model.reviews[left.id]?.dueAt ?? .distantPast
                let rightDue = model.reviews[right.id]?.dueAt ?? .distantPast
                return leftDue == rightDue ? left.id < right.id : leftDue < rightDue
            }
            .first
    }

    private var practice: PracticeItem? {
        let now = Date()
        let due = model.practices.filter {
            $0.isAvailable(in: track)
                && model.practiceRecords[$0.id]?.nextReviewAt.map { $0 <= now } == true
        }
        if let duePractice = due.sorted(by: comesBefore).first {
            return duePractice
        }
        return model.practices
            .filter { $0.isAvailable(in: track) && model.practiceRecords[$0.id] == nil }
            .sorted(by: comesBefore)
            .first
    }

    private var story: StaffStory? {
        model.stories
            .filter { !$0.isDeleted }
            .sorted { $0.updatedAt < $1.updatedAt }
            .first
    }

    private var dueReviewCount: Int {
        let now = Date()
        return model.flashcards.filter {
            (topic(for: $0).languageTrack == nil || topic(for: $0).languageTrack == track)
                && $0.isAvailable(in: track)
                && (model.reviews[$0.id]?.dueAt ?? .distantPast) <= now
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    eyebrow: "Focused preparation",
                    title: "Today's plan",
                    subtitle: "Build recall, practice under constraints, and rehearse one piece of your Staff narrative."
                )

                HStack(spacing: 14) {
                    summary(value: dueReviewCount, label: "cards ready")
                    summary(value: duePracticeCount, label: "re-solves due")
                    summary(value: completedPracticeCount, label: "practices complete")
                }

                VStack(spacing: 14) {
                    if let reviewCard {
                        PlanCard(
                            step: "01",
                            eyebrow: "Retrieval · 10 minutes",
                            title: reviewCard.question,
                            detail: reviewDetail(for: reviewCard),
                            actionTitle: "Review cards"
                        ) {
                            openTopic(topic(for: reviewCard))
                        }
                    }

                    if let practice {
                        PlanCard(
                            step: "02",
                            eyebrow: "Deliberate practice · 30–45 minutes",
                            title: practice.title,
                            detail: practiceDetail(for: practice),
                            actionTitle: "Open practice"
                        ) {
                            openPractice()
                        }
                    }

                    if let story {
                        PlanCard(
                            step: "03",
                            eyebrow: "Staff narrative · 10 minutes",
                            title: story.title,
                            detail: "Rehearse the stakes, your decisions, measurable result, and durable change. Then answer one follow-up without notes.",
                            actionTitle: "Rehearse story"
                        ) {
                            openCareer()
                        }
                    }
                }

                Text("The plan updates from your review schedule and recorded practice. Complete the three blocks in order, then use the topic library for deeper study.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 1_000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Today's Plan")
    }

    private var duePracticeCount: Int {
        let now = Date()
        return model.practiceRecords.values.filter {
            ($0.nextReviewAt ?? .distantFuture) <= now
        }.count
    }

    private var completedPracticeCount: Int {
        model.practiceRecords.values.filter { $0.status == .completed }.count
    }

    private func topic(for card: Flashcard) -> InterviewTopic {
        InterviewTopic(rawValue: card.topic) ?? .javaFundamentals
    }

    private func practiceDetail(for practice: PracticeItem) -> String {
        if model.practiceRecords[practice.id]?.nextReviewAt != nil {
            return "This is due for a re-solve. Work from an empty editor, then compare your decisions with the prior attempt."
        }
        if practicePriority(for: practice) > 0 {
            return "This exercise supports a weak area from your review history. Start a first attempt before reading any guide."
        }
        return "Start a first attempt and capture the evidence requested by the exercise before reading any guide."
    }

    private var weakTopics: [InterviewTopic: Int] {
        Dictionary(grouping: model.reviews.values.filter {
            $0.rating == .again || $0.rating == .hard
        }, by: { cardID in
            model.flashcards.first { $0.id == cardID.cardID }?.topic
        })
        .reduce(into: [:]) { result, entry in
            guard let topicName = entry.key, let topic = InterviewTopic(rawValue: topicName) else { return }
            guard topic.languageTrack == nil || topic.languageTrack == track else { return }
            result[topic] = entry.value.count
        }
    }

    private func reviewPriority(for card: Flashcard) -> Int {
        let cardPriority: Int
        switch model.reviews[card.id]?.rating {
        case .again?: cardPriority = 3
        case .hard?: cardPriority = 2
        default: cardPriority = 0
        }
        return cardPriority + (weakTopics[topic(for: card)] ?? 0)
    }

    private func practicePriority(for practice: PracticeItem) -> Int {
        let scorePriority = max(0, 3 - (model.practiceRecords[practice.id]?.score ?? 4))
        let topicPriority = weakTopics.reduce(0) { result, entry in
            practice.topic.localizedCaseInsensitiveContains(entry.key.rawValue)
                || entry.key.rawValue.localizedCaseInsensitiveContains(practice.topic)
                ? result + entry.value : result
        }
        return scorePriority + topicPriority
    }

    private func comesBefore(_ left: PracticeItem, _ right: PracticeItem) -> Bool {
        let leftPriority = practicePriority(for: left)
        let rightPriority = practicePriority(for: right)
        return leftPriority == rightPriority ? left.week < right.week : leftPriority > rightPriority
    }

    private func reviewDetail(for card: Flashcard) -> String {
        reviewPriority(for: card) > 0
            ? "This due card targets a weak area. Say the answer before revealing it, then rate it honestly."
            : "Start with your oldest due card in \(card.topic). Say the answer before revealing it."
    }

    private func summary(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(.title, design: .serif, weight: .semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.staffBorder)
        }
    }
}

private struct PlanCard: View {
    let step: String
    let eyebrow: String
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(step)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(Color.staffGreen)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.caption.bold())
                    .tracking(1)
                    .foregroundStyle(Color.staffGreen)
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.staffGreen)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.staffBorder)
        }
    }
}
