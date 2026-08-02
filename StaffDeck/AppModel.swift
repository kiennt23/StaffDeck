import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var flashcards: [Flashcard] = []
    @Published private(set) var practices: [PracticeItem] = []
    @Published var reviews: [Int: ReviewRecord] = [:]
    @Published var flashcardWork: [Int: FlashcardWork] = [:]
    @Published var practiceRecords: [String: PracticeRecord] = [:]
    @Published var profile: CareerProfile = Defaults.profile
    @Published var stories: [StaffStory] = Defaults.stories
    @Published var companies: [TargetCompany] = []
    @Published var contacts: [Contact] = []
    @Published var applications: [JobApplication] = []
    @Published var syncState: SyncState = .notConfigured

    private let store = TursoStore()
    private let cacheKey = "staff-deck-native-cache-v1"

    init() {
        do {
            flashcards = try ContentRepository.load([Flashcard].self, resource: "flashcards")
            practices = try ContentRepository.load([PracticeItem].self, resource: "practices")
        } catch {
            syncState = .offline("Bundled study content could not be loaded: \(error.localizedDescription)")
        }
        restoreCache()
    }

    func start() async {
        guard let credentials = KeychainStore.load() else {
            syncState = .notConfigured
            return
        }
        await connect(credentials)
    }

    func connect(_ credentials: TursoCredentials) async {
        syncState = .connecting
        do {
            try await store.connect(credentials: credentials)
            try KeychainStore.save(credentials)
            try await reconcileAll()
            syncState = .connected(Date())
            saveCache()
        } catch {
            syncState = .offline(error.localizedDescription)
        }
    }

    func disconnectAndForget() async {
        await store.disconnect()
        KeychainStore.delete()
        syncState = .notConfigured
    }

    func syncNow() async {
        guard let credentials = KeychainStore.load() else {
            syncState = .notConfigured
            return
        }
        await connect(credentials)
    }

    func rate(cardID: Int, rating: Rating, now: Date = Date()) {
        let previous = reviews[cardID]?.intervalDays ?? 1
        let interval: Int
        switch rating {
        case .again: interval = 0
        case .hard: interval = max(1, Int((Double(previous) * 1.4).rounded()))
        case .good: interval = max(2, Int((Double(previous) * 2.3).rounded()))
        case .easy: interval = max(4, Int((Double(previous) * 3.5).rounded()))
        }
        let dueAt = rating == .again
            ? now.addingTimeInterval(10 * 60)
            : Calendar.current.date(byAdding: .day, value: interval, to: now) ?? now
        let record = ReviewRecord(
            cardID: cardID,
            dueAt: dueAt,
            intervalDays: interval,
            rating: rating,
            reviews: (reviews[cardID]?.reviews ?? 0) + 1,
            updatedAt: now
        )
        reviews[cardID] = record
        saveCache()
        push(record, collection: "flashcard-progress", id: String(cardID), updatedAt: record.updatedAt)
    }

    func saveFlashcardWork(
        cardID: Int,
        answer: String,
        analysisNotes: String,
        answerDrawing: Data?,
        analysisDrawing: Data?
    ) {
        let previous = flashcardWork[cardID]
        guard
            previous?.answer != answer
                || previous?.analysisNotes != analysisNotes
                || previous?.answerDrawing != answerDrawing
                || previous?.analysisDrawing != analysisDrawing
        else {
            return
        }
        guard
            previous != nil
                || !answer.isEmpty
                || !analysisNotes.isEmpty
                || answerDrawing != nil
                || analysisDrawing != nil
        else {
            return
        }

        let record = FlashcardWork(
            cardID: cardID,
            answer: answer,
            analysisNotes: analysisNotes,
            answerDrawing: answerDrawing,
            analysisDrawing: analysisDrawing,
            updatedAt: Date()
        )
        flashcardWork[cardID] = record
        saveCache()
        push(
            record,
            collection: "flashcard-work",
            id: String(cardID),
            updatedAt: record.updatedAt
        )
    }

    func savePractice(
        itemID: String,
        status: PracticeStatus,
        score: Int?,
        notes: String,
        incrementAttempt: Bool = false
    ) {
        let now = Date()
        let previous = practiceRecords[itemID]
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
            updatedAt: now
        )
        practiceRecords[itemID] = record
        saveCache()
        push(record, collection: "practice-progress", id: itemID, updatedAt: now)
    }

    func saveProfile(_ next: CareerProfile) {
        var value = next
        value.updatedAt = Date()
        profile = value
        saveCache()
        push(value, collection: "career-profile", id: "default", updatedAt: value.updatedAt)
    }

    func saveStory(_ next: StaffStory) {
        saveCareer(next, in: &stories, collection: "career-stories")
    }

    func saveCompany(_ next: TargetCompany) {
        saveCareer(next, in: &companies, collection: "career-companies")
    }

    func saveContact(_ next: Contact) {
        saveCareer(next, in: &contacts, collection: "career-contacts")
    }

    func saveApplication(_ next: JobApplication) {
        saveCareer(next, in: &applications, collection: "career-applications")
    }

    func deleteStory(_ value: StaffStory) {
        deleteCareer(value, in: &stories, collection: "career-stories")
    }

    func deleteCompany(_ value: TargetCompany) {
        deleteCareer(value, in: &companies, collection: "career-companies")
    }

    func deleteContact(_ value: Contact) {
        deleteCareer(value, in: &contacts, collection: "career-contacts")
    }

    func deleteApplication(_ value: JobApplication) {
        deleteCareer(value, in: &applications, collection: "career-applications")
    }

    private func saveCareer<T: CareerRecord>(
        _ next: T,
        in records: inout [T],
        collection: String
    ) {
        var value = next
        value.updatedAt = Date()
        value.isDeleted = false
        if let index = records.firstIndex(where: { $0.id == value.id }) {
            records[index] = value
        } else {
            records.append(value)
        }
        saveCache()
        push(value, collection: collection, id: value.id, updatedAt: value.updatedAt)
    }

    private func deleteCareer<T: CareerRecord>(
        _ next: T,
        in records: inout [T],
        collection: String
    ) {
        var value = next
        value.updatedAt = Date()
        value.isDeleted = true
        if let index = records.firstIndex(where: { $0.id == value.id }) {
            records[index] = value
        }
        saveCache()
        push(
            value,
            collection: collection,
            id: value.id,
            updatedAt: value.updatedAt,
            isDeleted: true
        )
    }

    private func push<T: Encodable>(
        _ value: T,
        collection: String,
        id: String,
        updatedAt: Date,
        isDeleted: Bool = false
    ) {
        guard case .connected = syncState else { return }
        Task {
            do {
                try await store.upsert(
                    value,
                    collection: collection,
                    id: id,
                    updatedAt: updatedAt,
                    isDeleted: isDeleted
                )
                syncState = .connected(Date())
            } catch {
                syncState = .offline(error.localizedDescription)
            }
        }
    }

    private func reconcileAll() async throws {
        let remoteReviews = try await store.load(ReviewRecord.self, collection: "flashcard-progress")
        reviews = try await reconcile(
            local: Array(reviews.values),
            remote: remoteReviews,
            collection: "flashcard-progress",
            id: { String($0.cardID) },
            updatedAt: \.updatedAt
        ).reduce(into: [:]) { $0[$1.cardID] = $1 }

        let remoteFlashcardWork = try await store.load(
            FlashcardWork.self,
            collection: "flashcard-work"
        )
        flashcardWork = try await reconcile(
            local: Array(flashcardWork.values),
            remote: remoteFlashcardWork,
            collection: "flashcard-work",
            id: { String($0.cardID) },
            updatedAt: \.updatedAt
        ).reduce(into: [:]) { $0[$1.cardID] = $1 }

        let remotePractice = try await store.load(PracticeRecord.self, collection: "practice-progress")
        practiceRecords = try await reconcile(
            local: Array(practiceRecords.values),
            remote: remotePractice,
            collection: "practice-progress",
            id: \.practiceID,
            updatedAt: \.updatedAt
        ).reduce(into: [:]) { $0[$1.practiceID] = $1 }

        let remoteProfiles = try await store.load(CareerProfile.self, collection: "career-profile")
        if let remote = remoteProfiles.first, remote.updatedAt > profile.updatedAt {
            profile = remote
        } else {
            try await store.upsert(
                profile,
                collection: "career-profile",
                id: "default",
                updatedAt: profile.updatedAt
            )
        }

        stories = try await reconcileCareer(stories, collection: "career-stories")
        companies = try await reconcileCareer(companies, collection: "career-companies")
        contacts = try await reconcileCareer(contacts, collection: "career-contacts")
        applications = try await reconcileCareer(applications, collection: "career-applications")
    }

    private func reconcile<T: Codable>(
        local: [T],
        remote: [T],
        collection: String,
        id: (T) -> String,
        updatedAt: KeyPath<T, Date>
    ) async throws -> [T] {
        var merged = Dictionary(uniqueKeysWithValues: remote.map { (id($0), $0) })
        for value in local {
            let key = id(value)
            if let cloud = merged[key], cloud[keyPath: updatedAt] >= value[keyPath: updatedAt] {
                continue
            }
            merged[key] = value
            try await store.upsert(
                value,
                collection: collection,
                id: key,
                updatedAt: value[keyPath: updatedAt]
            )
        }
        return Array(merged.values)
    }

    private func reconcileCareer<T: CareerRecord>(
        _ local: [T],
        collection: String
    ) async throws -> [T] {
        let remote = try await store.load(T.self, collection: collection)
        var merged = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        for value in local {
            if let cloud = merged[value.id], cloud.updatedAt >= value.updatedAt {
                continue
            }
            merged[value.id] = value
            try await store.upsert(
                value,
                collection: collection,
                id: value.id,
                updatedAt: value.updatedAt,
                isDeleted: value.isDeleted
            )
        }
        return Array(merged.values)
    }

    private func saveCache() {
        let state = CachedState(
            reviews: reviews,
            flashcardWork: flashcardWork,
            practice: practiceRecords,
            profile: profile,
            stories: stories,
            companies: companies,
            contacts: contacts,
            applications: applications
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func restoreCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        guard let state = try? decoder.decode(CachedState.self, from: data) else { return }
        reviews = state.reviews
        flashcardWork = state.flashcardWork ?? [:]
        practiceRecords = state.practice
        profile = state.profile
        stories = state.stories
        companies = state.companies
        contacts = state.contacts
        applications = state.applications
    }
}

enum Defaults {
    static let baselineDate = Date(timeIntervalSince1970: 1)

    static let profile = CareerProfile(
        pitch: "Staff-level product and platform engineer with 14+ years of experience turning complex authorization, payments, compliance, and multi-cloud problems into operable systems. I combine Java and distributed-systems foundations with recent Go and TypeScript delivery, and I lead through architecture, incremental migration, and tools that multiply team effectiveness.",
        positioningNotes: "",
        updatedAt: baselineDate
    )

    static let stories: [StaffStory] = [
        StaffStory(
            id: "story-auth-platform",
            title: "Built a mission-critical authorization platform",
            signal: "Architecture · Security · Organizational leverage",
            situation: "Legacy permission checks could not safely express dynamic product and currency restrictions across expanding markets.",
            action: "Designed a modular OpenFGA model, migrated product access to fine-grained authorization, and built operations tooling for explicit onboarding controls.",
            result: "Created a shared dependency supporting five product types and 140+ currency pairs with P99 latency under 40 ms.",
            learning: "Centralized authorization needs explicit consistency, availability, audit, and fallback requirements because it becomes a critical blast-radius boundary.",
            updatedAt: baselineDate
        ),
        StaffStory(
            id: "story-regional-dashboard",
            title: "Led the regional dashboard expansion",
            signal: "Delivery leadership · Migration · Business impact",
            situation: "The company needed to enter new markets quickly without a risky rewrite of a growing merchant dashboard.",
            action: "Led a six-person frontend effort, applied the strangler pattern, and coordinated five cross-border product deliveries.",
            result: "Shipped the product line in under six months with zero-downtime modernization and roughly 30% faster initial load time.",
            learning: "Each migration increment should have independent value, observable compatibility, and a safe stopping point.",
            updatedAt: baselineDate
        ),
        StaffStory(
            id: "story-transaction-monitoring",
            title: "Built a transaction monitoring platform",
            signal: "Ambiguity · Compliance · Data systems",
            situation: "Risk teams needed real-time transaction evaluation, investigation workflows, and consolidated upstream data.",
            action: "Built the rule-management experience and core rule engine, integrated case management, and designed Kafka-backed ETL pipelines.",
            result: "Delivered an auditable compliance workflow from rule definition through alert generation and investigation.",
            learning: "Traceability and explainability are product requirements in regulated workflows.",
            updatedAt: baselineDate
        ),
    ]
}
