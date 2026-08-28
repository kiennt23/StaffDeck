import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var flashcards: [Flashcard] = []
    @Published private(set) var practices: [PracticeItem] = []
    @Published var reviews: [Int: ReviewRecord] = [:]
    @Published var flashcardWork: [Int: FlashcardWork] = [:]
    @Published var practiceRecords: [String: PracticeRecord] = [:]
    @Published var practiceAttempts: [String: [PracticeAttempt]] = [:]
    @Published var profile: CareerProfile = Defaults.profile
    @Published var stories: [StaffStory] = Defaults.stories
    @Published var companies: [TargetCompany] = []
    @Published var contacts: [Contact] = []
    @Published var applications: [JobApplication] = []
    @Published var syncState: SyncState = .notConfigured

    let dependencies: AppDependencies
    let cacheKey = "staff-deck-native-cache-v1"
    var pendingMutations: [SyncKey: SyncEnvelope] = [:]
    var flushTask: Task<Void, Never>?
    var syncGeneration = 0

    convenience init() {
        self.init(dependencies: .live)
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        do {
            flashcards = try ContentRepository.load([Flashcard].self, resource: "flashcards")
            practices = try ContentRepository.load([PracticeItem].self, resource: "practices")
        } catch {
            syncState = .offline("Bundled study content could not be loaded: \(error.localizedDescription)")
        }
        restoreCache()
    }

    var pendingMutationCount: Int { pendingMutations.count }

    func persistCache() throws {
        dependencies.cache.set(try SyncCoding.encoder.encode(cachedState()), forKey: cacheKey)
    }

    func cachedState() -> CachedState {
        CachedState(
            reviews: reviews,
            flashcardWork: flashcardWork,
            practice: practiceRecords,
            practiceAttempts: practiceAttempts,
            profile: profile,
            stories: stories,
            companies: companies,
            contacts: contacts,
            applications: applications,
            pendingMutations: pendingMutations.values.sorted(by: Self.outboxOrder)
        )
    }

    func restoreCache() {
        guard let data = dependencies.cache.data(forKey: cacheKey) else { return }
        do {
            let state = try SyncCoding.decoder.decode(CachedState.self, from: data)
            applyCachedState(state)
        } catch {
            syncState = .offline("Cached state could not be restored: \(error.localizedDescription)")
        }
    }

    func applyCachedState(_ state: CachedState) {
        reviews = state.reviews
        flashcardWork = state.flashcardWork
        practiceRecords = state.practice
        practiceAttempts = state.practiceAttempts
        profile = state.profile
        stories = state.stories
        companies = state.companies
        contacts = state.contacts
        applications = state.applications
        pendingMutations = [:]
        for mutation in state.pendingMutations {
            if let previous = pendingMutations[mutation.key],
               previous.updatedAtMilliseconds > mutation.updatedAtMilliseconds { continue }
            pendingMutations[mutation.key] = mutation
        }
    }

    static func outboxOrder(_ lhs: SyncEnvelope, _ rhs: SyncEnvelope) -> Bool {
        if lhs.updatedAtMilliseconds != rhs.updatedAtMilliseconds {
            return lhs.updatedAtMilliseconds < rhs.updatedAtMilliseconds
        }
        if lhs.collection.rawValue != rhs.collection.rawValue {
            return lhs.collection.rawValue < rhs.collection.rawValue
        }
        return lhs.recordID < rhs.recordID
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
