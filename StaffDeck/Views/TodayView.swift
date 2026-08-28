import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    let track: LanguageTrack
    let openTopic: (InterviewTopic, Int?) -> Void
    let openPractice: (String?) -> Void
    let openCareer: (String?) -> Void

    private var recommendations: TodayRecommendations {
        TodayRecommendations.evaluate(
            track: track,
            flashcards: model.flashcards,
            practices: model.practices,
            reviews: model.reviews,
            practiceRecords: model.practiceRecords,
            stories: model.stories,
            now: model.dependencies.dateSource.now()
        )
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
                    summary(value: recommendations.dueReviewCount, label: "cards ready")
                    summary(value: recommendations.duePracticeCount, label: "re-solves due")
                    summary(value: recommendations.completedPracticeCount, label: "practices complete")
                }

                VStack(spacing: 14) {
                    if let reviewCard = recommendations.reviewCard {
                        PlanCard(
                            step: "01",
                            eyebrow: "Retrieval · 10 minutes",
                            title: reviewCard.question,
                            detail: recommendations.reviewReason,
                            actionTitle: "Review cards"
                        ) {
                            openTopic(topic(for: reviewCard), reviewCard.id)
                        }
                    }

                    if let practice = recommendations.practice {
                        PlanCard(
                            step: "02",
                            eyebrow: "Deliberate practice · 30–45 minutes",
                            title: practice.title,
                            detail: recommendations.practiceReason,
                            actionTitle: "Open practice"
                        ) {
                            openPractice(practice.id)
                        }
                    }

                    if let story = recommendations.story {
                        PlanCard(
                            step: "03",
                            eyebrow: "Staff narrative · 10 minutes",
                            title: story.title,
                            detail: "Rehearse the stakes, your decisions, measurable result, and durable change. Then answer one follow-up without notes.",
                            actionTitle: "Rehearse story"
                        ) {
                            openCareer(story.id)
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

    private func topic(for card: Flashcard) -> InterviewTopic {
        InterviewTopic(rawValue: card.topic) ?? .javaFundamentals
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
