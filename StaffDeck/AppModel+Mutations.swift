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
        let scheduled = AdaptiveScheduler.schedule(
            rating: rating,
            currentRecord: reviews[cardID],
            now: now,
            calendar: dependencies.calendar
        )
        let record = ReviewRecord(
            cardID: cardID,
            dueAt: scheduled.dueAt,
            intervalDays: scheduled.intervalDays,
            rating: rating,
            reviews: scheduled.reviews,
            ease: scheduled.ease,
            lapses: scheduled.lapses,
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

    func savePracticeDraft(
        itemID: String,
        status: PracticeStatus = .notStarted,
        score: Int? = nil,
        notes: String = "",
        artifact: String = "",
        satisfiedCriterionIDs: [String] = []
    ) {
        let previous = practiceRecords[itemID]
        let attempts = previous?.attempts ?? 0
        let legacyBaseline = previous?.legacyAttemptBaseline ?? attempts

        if let previous {
            if previous.status == status
                && previous.score == score
                && previous.notes == notes
                && previous.draftArtifact == artifact
                && previous.draftSatisfiedCriterionIDs == satisfiedCriterionIDs {
                return
            }
        } else if status == .notStarted
            && score == nil
            && notes.isEmpty
            && artifact.isEmpty
            && satisfiedCriterionIDs.isEmpty {
            return
        }

        let key = SyncKey(collection: .practice, recordID: itemID)
        let now = dependencies.dateSource.now()
        let milliseconds = nextMilliseconds(key: key, current: previous?.updatedAt, candidate: now)
        let nextReview = AdaptiveScheduler.schedulePractice(
            status: status,
            score: score,
            attempts: attempts,
            now: now,
            calendar: dependencies.calendar
        )
        let record = PracticeRecord(
            practiceID: itemID,
            status: status,
            score: score,
            notes: notes,
            attempts: attempts,
            draftArtifact: artifact,
            draftSatisfiedCriterionIDs: satisfiedCriterionIDs,
            legacyAttemptBaseline: legacyBaseline,
            nextReviewAt: nextReview,
            updatedAt: Self.date(milliseconds)
        )
        practiceRecords[itemID] = record
        enqueue(record, key: key, milliseconds: milliseconds)
    }

    @discardableResult
    func submitPracticeAttempt(
        itemID: String,
        score: Int? = nil,
        notes: String = "",
        artifact: String,
        satisfiedCriterionIDs: [String]
    ) throws -> PracticeAttempt {
        guard let item = practices.first(where: { $0.id == itemID }) else {
            throw PracticeSubmissionError.unknownPractice(itemID)
        }

        let normalizedArtifact = artifact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedArtifact.isEmpty else {
            throw PracticeSubmissionError.emptyArtifact
        }

        guard !satisfiedCriterionIDs.isEmpty else {
            throw PracticeSubmissionError.noCriteriaSelected
        }

        let validCriterionIDs = Set(item.completionCriteria.map(\.id))
        for id in satisfiedCriterionIDs {
            guard validCriterionIDs.contains(id) else {
                throw PracticeSubmissionError.invalidCriterionID(id)
            }
        }

        let selectedSet = Set(satisfiedCriterionIDs)
        let orderedCriterionIDs = item.completionCriteria.map(\.id).filter { selectedSet.contains($0) }

        let isCompleted = !item.completionCriteria.isEmpty && orderedCriterionIDs.count == item.completionCriteria.count
        let derivedStatus: PracticeStatus = isCompleted ? .completed : .attempted

        let previous = practiceRecords[itemID]
        let legacyBaseline = previous?.legacyAttemptBaseline ?? (previous?.attempts ?? 0)
        let attemptsCount = (previous?.attempts ?? 0) + 1

        let now = dependencies.dateSource.now()
        let nextReview = AdaptiveScheduler.schedulePractice(
            status: derivedStatus,
            score: score,
            attempts: attemptsCount,
            now: now,
            calendar: dependencies.calendar
        )

        let attemptID = UUID().uuidString
        let attemptKey = SyncKey(collection: .practiceAttempts, recordID: attemptID)
        let recordKey = SyncKey(collection: .practice, recordID: itemID)

        let recordMillis = nextMilliseconds(key: recordKey, current: previous?.updatedAt, candidate: now)
        let attemptMillis = nextMilliseconds(key: attemptKey, current: nil, candidate: now)

        let recordDate = Self.date(recordMillis)
        let attemptDate = Self.date(attemptMillis)

        let submission = PracticeSubmissionEvidence(
            artifact: artifact,
            satisfiedCriterionIDs: orderedCriterionIDs
        )

        let attempt = PracticeAttempt(
            id: attemptID,
            practiceID: itemID,
            status: derivedStatus,
            score: score,
            notes: notes,
            submission: submission,
            completedAt: now,
            updatedAt: attemptDate
        )

        let record = PracticeRecord(
            practiceID: itemID,
            status: derivedStatus,
            score: score,
            notes: notes,
            attempts: attemptsCount,
            draftArtifact: artifact,
            draftSatisfiedCriterionIDs: orderedCriterionIDs,
            legacyAttemptBaseline: legacyBaseline,
            nextReviewAt: nextReview,
            updatedAt: recordDate
        )

        let recordEnvelope = try SyncEnvelope.encode(
            record,
            collection: .practice,
            recordID: itemID,
            updatedAtMilliseconds: recordMillis
        )
        let attemptEnvelope = try SyncEnvelope.encode(
            attempt,
            collection: .practiceAttempts,
            recordID: attemptID,
            updatedAtMilliseconds: attemptMillis
        )

        practiceRecords[itemID] = record
        var existingAttempts = practiceAttempts[itemID] ?? []
        existingAttempts.append(attempt)
        practiceAttempts[itemID] = existingAttempts

        enqueue([recordEnvelope, attemptEnvelope])

        return attempt
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

enum PracticeSubmissionError: LocalizedError, Equatable {
    case unknownPractice(String)
    case emptyArtifact
    case noCriteriaSelected
    case invalidCriterionID(String)

    var errorDescription: String? {
        switch self {
        case .unknownPractice(let id):
            return "Practice exercise '\(id)' was not found."
        case .emptyArtifact:
            return "Evidence artifact cannot be empty."
        case .noCriteriaSelected:
            return "At least one completion criterion must be selected."
        case .invalidCriterionID(let id):
            return "Criterion '\(id)' does not belong to this practice exercise."
        }
    }
}
