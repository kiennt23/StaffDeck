import Foundation

extension AppModel {
    func rate(cardID: Int, rating: Rating) {
        rate(cardID: cardID, rating: rating, now: dependencies.dateSource.now())
    }

    func rate(cardID: Int, rating: Rating, now: Date) {
        let key = SyncKey(collection: .reviews, recordID: String(cardID))
        let milliseconds = nextMilliseconds(
            key: key,
            current: reviews[cardID]?.updatedAt,
            candidate: now
        )
        let previous = reviews[cardID]?.intervalDays ?? 1
        let interval: Int
        switch rating {
        case .again: interval = 0
        case .hard: interval = max(1, Int((Double(previous) * 1.4).rounded()))
        case .good: interval = max(2, Int((Double(previous) * 2.3).rounded()))
        case .easy: interval = max(4, Int((Double(previous) * 3.5).rounded()))
        }
        let dueAt = rating == .again
            ? now.addingTimeInterval(600)
            : Calendar.current.date(byAdding: .day, value: interval, to: now) ?? now
        let record = ReviewRecord(
            cardID: cardID,
            dueAt: dueAt,
            intervalDays: interval,
            rating: rating,
            reviews: (reviews[cardID]?.reviews ?? 0) + 1,
            updatedAt: Self.date(milliseconds)
        )
        reviews[cardID] = record
        enqueue(record, key: key, milliseconds: milliseconds)
    }

    func saveFlashcardWork(
        cardID: Int,
        answer: String,
        analysisNotes: String,
        answerDrawing: Data?,
        analysisDrawing: Data?
    ) {
        let previous = flashcardWork[cardID]
        guard previous?.answer != answer
            || previous?.analysisNotes != analysisNotes
            || previous?.answerDrawing != answerDrawing
            || previous?.analysisDrawing != analysisDrawing else { return }
        guard previous != nil || !answer.isEmpty || !analysisNotes.isEmpty
            || answerDrawing != nil || analysisDrawing != nil else { return }

        let key = SyncKey(collection: .flashcardWork, recordID: String(cardID))
        let milliseconds = nextMilliseconds(key: key, current: previous?.updatedAt)
        let record = FlashcardWork(
            cardID: cardID,
            answer: answer,
            analysisNotes: analysisNotes,
            answerDrawing: answerDrawing,
            analysisDrawing: analysisDrawing,
            updatedAt: Self.date(milliseconds)
        )
        flashcardWork[cardID] = record
        enqueue(record, key: key, milliseconds: milliseconds)
    }

    func savePractice(
        itemID: String,
        status: PracticeStatus,
        score: Int?,
        notes: String,
        incrementAttempt: Bool = false
    ) {
        let previous = practiceRecords[itemID]
        let key = SyncKey(collection: .practice, recordID: itemID)
        let now = dependencies.dateSource.now()
        let milliseconds = nextMilliseconds(key: key, current: previous?.updatedAt, candidate: now)
        let reviewDays = status == .completed && (score ?? 0) >= 3 ? 14 : 2
        let record = PracticeRecord(
            practiceID: itemID,
            status: status,
            score: score,
            notes: notes,
            attempts: (previous?.attempts ?? 0) + (incrementAttempt ? 1 : 0),
            nextReviewAt: status == .notStarted
                ? nil
                : Calendar.current.date(byAdding: .day, value: reviewDays, to: now),
            updatedAt: Self.date(milliseconds)
        )
        practiceRecords[itemID] = record
        enqueue(record, key: key, milliseconds: milliseconds)
    }

    func saveProfile(_ next: CareerProfile) {
        let key = SyncKey(collection: .profile, recordID: "default")
        let milliseconds = nextMilliseconds(key: key, current: profile.updatedAt)
        var value = next
        value.updatedAt = Self.date(milliseconds)
        profile = value
        enqueue(value, key: key, milliseconds: milliseconds)
    }

    func saveStory(_ next: StaffStory) { stories = saveCareer(next, in: stories, collection: .stories) }
    func saveCompany(_ next: TargetCompany) { companies = saveCareer(next, in: companies, collection: .companies) }
    func saveContact(_ next: Contact) { contacts = saveCareer(next, in: contacts, collection: .contacts) }
    func saveApplication(_ next: JobApplication) {
        applications = saveCareer(next, in: applications, collection: .applications)
    }

    func deleteStory(_ value: StaffStory) { stories = deleteCareer(value, in: stories, collection: .stories) }
    func deleteCompany(_ value: TargetCompany) { companies = deleteCareer(value, in: companies, collection: .companies) }
    func deleteContact(_ value: Contact) { contacts = deleteCareer(value, in: contacts, collection: .contacts) }
    func deleteApplication(_ value: JobApplication) {
        applications = deleteCareer(value, in: applications, collection: .applications)
    }

    private func saveCareer<Value: CareerRecord>(
        _ next: Value,
        in records: [Value],
        collection: SyncCollection
    ) -> [Value] {
        var result = records
        let key = SyncKey(collection: collection, recordID: next.id)
        let current = result.first { $0.id == next.id }
        let milliseconds = nextMilliseconds(key: key, current: current?.updatedAt)
        var value = next
        value.updatedAt = Self.date(milliseconds)
        value.isDeleted = false
        replaceOrAppend(value, in: &result)
        enqueue(value, key: key, milliseconds: milliseconds)
        return result
    }

    private func deleteCareer<Value: CareerRecord>(
        _ next: Value,
        in records: [Value],
        collection: SyncCollection
    ) -> [Value] {
        var result = records
        let key = SyncKey(collection: collection, recordID: next.id)
        let current = result.first { $0.id == next.id }
        let milliseconds = nextMilliseconds(key: key, current: current?.updatedAt ?? next.updatedAt)
        var value = current ?? next
        value.updatedAt = Self.date(milliseconds)
        value.isDeleted = true
        replaceOrAppend(value, in: &result)
        enqueue(value, key: key, milliseconds: milliseconds, isDeleted: true)
        return result
    }

    private func replaceOrAppend<Value: CareerRecord>(_ value: Value, in records: inout [Value]) {
        if let index = records.firstIndex(where: { $0.id == value.id }) {
            records[index] = value
        } else {
            records.append(value)
        }
    }
}
