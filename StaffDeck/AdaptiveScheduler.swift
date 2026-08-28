import Foundation

struct ScheduledReview: Equatable {
    let intervalDays: Int
    let dueAt: Date
    let ease: Double
    let lapses: Int
    let reviews: Int
}

enum AdaptiveScheduler {
    static let defaultEase: Double = 2.5
    static let minEase: Double = 1.3

    static func schedule(
        rating: Rating,
        currentRecord: ReviewRecord?,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> ScheduledReview {
        let currentReviews = currentRecord?.reviews ?? 0
        let currentEase = currentRecord?.ease ?? defaultEase
        let currentLapses = currentRecord?.lapses ?? 0
        let previousInterval = currentRecord?.intervalDays ?? 1

        let newEase: Double
        let newLapses: Int
        let interval: Int
        let dueAt: Date

        switch rating {
        case .again:
            newEase = max(minEase, currentEase - 0.2)
            newLapses = currentLapses + 1
            interval = 0
            dueAt = now.addingTimeInterval(600) // 10 minutes
        case .hard:
            newEase = max(minEase, currentEase - 0.15)
            newLapses = currentLapses
            interval = max(1, Int((Double(previousInterval) * 1.4).rounded()))
            dueAt = calendar.date(byAdding: .day, value: interval, to: now) ?? now
        case .good:
            newEase = currentEase
            newLapses = currentLapses
            interval = max(2, Int((Double(previousInterval) * 2.3).rounded()))
            dueAt = calendar.date(byAdding: .day, value: interval, to: now) ?? now
        case .easy:
            newEase = currentEase + 0.15
            newLapses = currentLapses
            interval = max(4, Int((Double(previousInterval) * 3.5).rounded()))
            dueAt = calendar.date(byAdding: .day, value: interval, to: now) ?? now
        }

        return ScheduledReview(
            intervalDays: interval,
            dueAt: dueAt,
            ease: newEase,
            lapses: newLapses,
            reviews: currentReviews + 1
        )
    }

    static func schedulePractice(
        status: PracticeStatus,
        score: Int?,
        attempts: Int,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        guard status != .notStarted else { return nil }
        let scoreValue = score ?? 0
        let reviewDays: Int
        if status == .completed && scoreValue >= 3 {
            reviewDays = attempts > 1 ? 30 : 14
        } else {
            reviewDays = 2
        }
        return calendar.date(byAdding: .day, value: reviewDays, to: now)
    }
}
