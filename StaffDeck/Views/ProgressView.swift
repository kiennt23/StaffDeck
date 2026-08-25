import SwiftUI

struct LearningProgressView: View {
    @EnvironmentObject private var model: AppModel
    let track: LanguageTrack
    let openTopic: (InterviewTopic) -> Void

    private var topics: [InterviewTopic] {
        InterviewTopic.topics(for: track)
    }

    private var baselineCards: [Flashcard] {
        topics.compactMap { topic in
            model.flashcards.first { $0.topic == topic.rawValue && $0.isAvailable(in: track) }
        }
    }

    private var nextBaselineCard: Flashcard? {
        baselineCards.first { model.reviews[$0.id] == nil }
    }

    private var assessedTopics: Int {
        baselineCards.filter { model.reviews[$0.id] != nil }.count
    }

    private var metrics: LearningProgressMetrics {
        LearningProgressMetrics(
            track: track,
            flashcards: model.flashcards,
            practices: model.practices,
            reviews: model.reviews,
            practiceRecords: model.practiceRecords
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    eyebrow: "Evidence-led preparation",
                    title: "Progress and weak spots",
                    subtitle: "Use a short baseline to identify where to spend deliberate practice—not where study feels most comfortable."
                )

                HStack(spacing: 14) {
                    metric("\(assessedTopics) / \(baselineCards.count)", "topics assessed")
                    metric("\(metrics.cardsReviewed)", "cards reviewed")
                    metric(practiceAverage, "average practice score")
                }

                GroupBox("\(baselineCards.count)-question baseline") {
                    VStack(alignment: .leading, spacing: 14) {
                        if let card = nextBaselineCard {
                            Text("Topic \(assessedTopics + 1) of \(baselineCards.count) · \(card.topic)")
                                .font(.caption.bold())
                                .foregroundStyle(Color.staffGreen)
                            Text(card.question)
                                .font(.title3.weight(.semibold))
                            Text("Answer aloud first, then rate the answer honestly. This uses your normal review schedule, so nothing is duplicated.")
                                .foregroundStyle(.secondary)
                            HStack {
                                ForEach(Rating.allCases) { rating in
                                    Button(rating.title) {
                                        model.rate(cardID: card.id, rating: rating)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(tint(for: rating))
                                }
                            }
                        } else {
                            Label("Baseline complete. Use the map below to select the next focused topic.", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.top, 8)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("WEAKNESS MAP")
                        .font(.caption.bold())
                        .tracking(1)
                        .foregroundStyle(Color.staffGreen)
                    ForEach(topics) { topic in
                        topicRow(topic)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1_000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Progress")
    }

    private var practiceAverage: String {
        guard let average = metrics.averagePracticeScore else { return "—" }
        return String(format: "%.1f / 4", average)
    }

    private func topicRow(_ topic: InterviewTopic) -> some View {
        let cards = model.flashcards.filter {
            $0.topic == topic.rawValue && $0.isAvailable(in: track)
        }
        let records = cards.compactMap { model.reviews[$0.id] }
        let weakCount = records.filter { $0.rating == .again || $0.rating == .hard }.count
        let status: (String, Color) = records.isEmpty
            ? ("Not assessed", .secondary)
            : weakCount > 0 ? ("Needs review", .orange) : ("Building evidence", .green)

        return Button {
            openTopic(topic)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: topic.systemImage)
                    .foregroundStyle(Color.staffGreen)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(topic.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(records.count) of \(cards.count) reviewed · \(weakCount) hard or again")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(status.0)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.1)
            }
            .padding(14)
            .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.staffBorder)
            }
        }
        .buttonStyle(.plain)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title, design: .serif, weight: .semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.staffBorder) }
    }

    private func tint(for rating: Rating) -> Color {
        switch rating {
        case .again: .red
        case .hard: .orange
        case .good: .green
        case .easy: .blue
        }
    }
}

struct LearningProgressMetrics {
    let cardsReviewed: Int
    let averagePracticeScore: Double?

    init(
        track: LanguageTrack,
        flashcards: [Flashcard],
        practices: [PracticeItem],
        reviews: [Int: ReviewRecord],
        practiceRecords: [String: PracticeRecord]
    ) {
        let availableCardIDs = Set(flashcards.filter { $0.isAvailable(in: track) }.map(\.id))
        self.cardsReviewed = reviews.values.filter { availableCardIDs.contains($0.cardID) }.count

        let availablePracticeIDs = Set(practices.filter { $0.isAvailable(in: track) }.map(\.id))
        let scores = practiceRecords.values.compactMap { record -> Int? in
            guard availablePracticeIDs.contains(record.practiceID) else { return nil }
            return record.score
        }
        if scores.isEmpty {
            self.averagePracticeScore = nil
        } else {
            self.averagePracticeScore = Double(scores.reduce(0, +)) / Double(scores.count)
        }
    }
}
