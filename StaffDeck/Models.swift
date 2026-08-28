import Foundation

enum InterviewTopicGroup: String, CaseIterable, Identifiable {
    case foundations = "Foundations"
    case systems = "Systems & Platform"
    case staff = "Staff Practice"

    var id: String { rawValue }
}

enum LanguageTrack: String, CaseIterable, Identifiable, Codable {
    case java
    case go

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var defaultTopic: InterviewTopic {
        switch self {
        case .java: .javaFundamentals
        case .go: .goFundamentals
        }
    }
}

enum InterviewTopic: String, CaseIterable, Identifiable {
    case javaFundamentals = "Java Fundamentals"
    case javaAPI = "Java & API"
    case jvmConcurrency = "JVM & Concurrency"
    case spring = "Spring"
    case dsa = "DSA"
    case databases = "Databases"
    case systemDesign = "System Design"
    case security = "Security"
    case cloudPlatform = "Cloud & Platform"
    case reliability = "Reliability"
    case leadership = "Leadership"
    case staffScenarios = "Staff Scenarios"
    case goFundamentals = "Go Fundamentals"
    case goServices = "Go APIs & Services"
    case goConcurrency = "Go Concurrency & Runtime"
    case goArchitecture = "Go Service Architecture"

    var id: String { rawValue }

    var group: InterviewTopicGroup {
        switch self {
        case .javaFundamentals, .javaAPI, .jvmConcurrency, .spring,
                .goFundamentals, .goServices, .goConcurrency, .goArchitecture, .dsa:
            .foundations
        case .databases, .systemDesign, .security, .cloudPlatform, .reliability:
            .systems
        case .leadership, .staffScenarios:
            .staff
        }
    }

    var systemImage: String {
        switch self {
        case .javaFundamentals: "text.book.closed"
        case .javaAPI: "shippingbox"
        case .jvmConcurrency: "cpu"
        case .spring: "leaf"
        case .dsa: "function"
        case .databases: "cylinder"
        case .systemDesign: "point.3.connected.trianglepath.dotted"
        case .security: "lock.shield"
        case .cloudPlatform: "cloud"
        case .reliability: "waveform.path.ecg"
        case .leadership: "person.3"
        case .staffScenarios: "scope"
        case .goFundamentals: "g.circle"
        case .goServices: "network"
        case .goConcurrency: "arrow.triangle.branch"
        case .goArchitecture: "shippingbox.and.arrow.backward"
        }
    }

    var languageTrack: LanguageTrack? {
        switch self {
        case .javaFundamentals, .javaAPI, .jvmConcurrency, .spring: .java
        case .goFundamentals, .goServices, .goConcurrency, .goArchitecture: .go
        default: nil
        }
    }

    static func topics(in group: InterviewTopicGroup, track: LanguageTrack) -> [InterviewTopic] {
        allCases
            .filter { $0.group == group && ($0.languageTrack == nil || $0.languageTrack == track) }
            .sorted { left, right in
                let leftIsTrackSpecific = left.languageTrack == track
                let rightIsTrackSpecific = right.languageTrack == track
                if leftIsTrackSpecific != rightIsTrackSpecific {
                    return leftIsTrackSpecific
                }
                return left.sortOrder < right.sortOrder
            }
    }

    static func topics(for track: LanguageTrack) -> [InterviewTopic] {
        InterviewTopicGroup.allCases.flatMap { topics(in: $0, track: track) }
    }

    private var sortOrder: Int {
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }
}

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case today = "Today's Plan"
    case progress = "Progress"
    case compare = "Compare Languages"
    case practice = "Practice Lab"
    case career = "Career Hub"
    case settings = "Sync Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .progress: "chart.bar.xaxis"
        case .compare: "arrow.left.arrow.right"
        case .practice: "hammer"
        case .career: "briefcase"
        case .settings: "arrow.triangle.2.circlepath"
        }
    }
}

enum SidebarDestination: Hashable {
    case topic(InterviewTopic, targetCardID: Int? = nil)
    case workspace(WorkspaceSection, targetItemID: String? = nil)

    func resolved(for track: LanguageTrack) -> SidebarDestination {
        switch self {
        case let .workspace(section, targetItemID):
            .workspace(section, targetItemID: targetItemID)
        case let .topic(topic, targetCardID):
            topic.languageTrack == nil || topic.languageTrack == track
                ? .topic(topic, targetCardID: targetCardID)
                : .topic(track.defaultTopic, targetCardID: nil)
        }
    }
}

enum FundamentalTopic: String, Codable, CaseIterable, Identifiable {
    case languageSemantics = "Language Semantics & Values"
    case objectModel = "Object Model & Initialization"
    case collections = "Collections & Ordering"
    case functionalJava = "Functional Java"
    case exceptions = "Exceptions & Resources"
    case modernTypes = "Generics & Modern Types"
    case runtime = "Runtime, Annotations & Modules"
    case testingDependencies = "Testing & Dependency Management"

    var id: String { rawValue }

    var sortOrder: Int {
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }
}

enum GoFundamentalTopic: String, Codable, CaseIterable, Identifiable {
    case typesInterfaces = "Types & Interfaces"
    case errors = "Errors & Control Flow"
    case ownership = "Slices, Maps & Ownership"
    case collections = "Collections & Interview Idioms"
    case structsMethods = "Structs, Methods & Embedding"
    case functionsGenerics = "Functions, Generics & Composition"
    case modulesTooling = "Modules, Tooling & Build Semantics"

    var id: String { rawValue }

    var sortOrder: Int {
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }
}

enum ConcurrencySubtopic: String, CaseIterable, Identifiable {
    case memorySynchronization = "Memory & Synchronization"
    case lifecycleCancellation = "Lifecycle & Cancellation"
    case capacityBackpressure = "Capacity & Backpressure"
    case runtimeDiagnostics = "Runtime Diagnostics"

    var id: String { rawValue }
}

enum ServiceSubtopic: String, CaseIterable, Identifiable {
    case apiDesign = "HTTP, gRPC & API Design"
    case contractsData = "Contracts, Types & Data"
    case clientsRetries = "Clients, Timeouts & Retries"
    case testing = "Service Testing"

    var id: String { rawValue }
}

enum DatabaseSubtopic: String, CaseIterable, Identifiable {
    case modelingMigration = "Modeling & Schema Evolution"
    case queriesIndexing = "Query Design & Indexing"
    case transactionsConsistency = "Transactions & Consistency"
    case poolsRecovery = "Pools, Timeouts & Recovery"
    case rolloutDiagnosis = "Migrations, Rollouts & Diagnosis"

    var id: String { rawValue }
}

enum SecuritySubtopic: String, CaseIterable, Identifiable {
    case identityTenancy = "Authentication, Authorization & Tenancy"
    case secretsSupplyChain = "Secrets & Supply Chain"
    case inputExposure = "Input Validation & Data Exposure"
    case auditIncident = "Auditability & Incident Response"
    case guardrailsRollout = "Security Guardrails & Rollout"

    var id: String { rawValue }
}

enum ReliabilitySubtopic: String, CaseIterable, Identifiable {
    case objectives = "SLOs, SLIs & Error Budgets"
    case observability = "Observability"
    case capacity = "Capacity, Overload & Backpressure"
    case delivery = "Deployments & Rollbacks"
    case incidents = "Incidents & Resilience Testing"
    var id: String { rawValue }
}

enum PlatformSubtopic: String, CaseIterable, Identifiable {
    case containers = "Containers, Kubernetes & Resource Limits"
    case networking = "Networking & Service Connectivity"
    case configuration = "Configuration, Secrets & Environment Parity"
    case delivery = "CI/CD, Progressive Delivery & Rollback"
    case pavedRoad = "Platform Paved Roads & Adoption"
    var id: String { rawValue }
}

struct Flashcard: Codable, Identifiable, Hashable {
    let id: Int
    let topic: String
    let contentTrack: LanguageTrack?
    let subtopic: String?
    let question: String
    let testing: String
    let outline: [String]
    let answer: String
    let example: String
    let staffSignal: String
    let followUps: [String]

    func isAvailable(in track: LanguageTrack) -> Bool {
        guard let topic = InterviewTopic(rawValue: topic) else { return false }
        if let contentTrack, contentTrack != track { return false }
        guard topic.languageTrack == nil || topic.languageTrack == track else { return false }
        return track != .go || !Self.javaOnlySharedCardIDs.contains(id)
    }

    private static let javaOnlySharedCardIDs: Set<Int> = [73, 79, 82, 121, 134]
}

struct PracticeGuide: Codable, Hashable {
    let recognition: String
    let invariant: String
    let anchorProblem: String
    let answer: String
    let complexity: String
    let pitfalls: [String]
}

struct GeneralPracticeRubric: Hashable {
    let signals: [String]
    let strongAnswer: [String]
    let commonMisses: [String]
    let scoreGuide: String
}

enum GeneralPracticeRubricKind: String, Codable, CaseIterable, Identifiable {
    case coding, design, debug, communication

    var id: String { rawValue }

    var rubric: GeneralPracticeRubric {
        switch self {
        case .coding: PracticeItem.codingRubric
        case .design: PracticeItem.designRubric
        case .debug: PracticeItem.debugRubric
        case .communication: PracticeItem.communicationRubric
        }
    }
}

struct PracticeCompletionCriterion: Codable, Identifiable, Hashable {
    var id: String
    var requirement: String
    var evidencePrompt: String

    init(id: String, requirement: String, evidencePrompt: String) {
        self.id = id
        self.requirement = requirement
        self.evidencePrompt = evidencePrompt
    }
}

struct PracticeSubmissionEvidence: Codable, Hashable {
    var artifact: String
    var satisfiedCriterionIDs: [String]

    init(artifact: String = "", satisfiedCriterionIDs: [String] = []) {
        self.artifact = artifact
        self.satisfiedCriterionIDs = satisfiedCriterionIDs
    }
}

struct PracticeItem: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let contentTrack: LanguageTrack?
    let competencyTopics: [InterviewTopic]
    let rubricKind: GeneralPracticeRubricKind?
    let topic: String
    let week: Int
    let number: Int
    let title: String
    let prompt: String
    let artifact: String
    let followUps: [String]
    let completion: String
    let completionCriteria: [PracticeCompletionCriterion]
    let guide: PracticeGuide?
    let modelAnswer: [String]?

    enum CodingKeys: String, CodingKey {
        case id, kind, contentTrack, competencyTopics, rubricKind, topic, week, number, title, prompt, artifact, followUps, completion, completionCriteria, guide, modelAnswer
    }

    init(
        id: String,
        kind: String,
        contentTrack: LanguageTrack? = nil,
        competencyTopics: [InterviewTopic] = [],
        rubricKind: GeneralPracticeRubricKind? = nil,
        topic: String,
        week: Int,
        number: Int,
        title: String,
        prompt: String,
        artifact: String,
        followUps: [String] = [],
        completion: String = "",
        completionCriteria: [PracticeCompletionCriterion]? = nil,
        guide: PracticeGuide? = nil,
        modelAnswer: [String]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.contentTrack = contentTrack
        self.competencyTopics = competencyTopics
        self.rubricKind = rubricKind
        self.topic = topic
        self.week = week
        self.number = number
        self.title = title
        self.prompt = prompt
        self.artifact = artifact
        self.followUps = followUps
        self.completion = completion
        if let completionCriteria {
            self.completionCriteria = completionCriteria
        } else if !completion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.completionCriteria = [
                PracticeCompletionCriterion(
                    id: "legacy-completion",
                    requirement: completion,
                    evidencePrompt: artifact
                )
            ]
        } else {
            self.completionCriteria = []
        }
        self.guide = guide
        self.modelAnswer = modelAnswer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(String.self, forKey: .kind)
        contentTrack = try container.decodeIfPresent(LanguageTrack.self, forKey: .contentTrack)
        topic = try container.decode(String.self, forKey: .topic)
        week = try container.decode(Int.self, forKey: .week)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        prompt = try container.decode(String.self, forKey: .prompt)
        artifact = try container.decode(String.self, forKey: .artifact)
        followUps = try container.decode([String].self, forKey: .followUps)
        completion = try container.decodeIfPresent(String.self, forKey: .completion) ?? ""
        guide = try container.decodeIfPresent(PracticeGuide.self, forKey: .guide)
        modelAnswer = try container.decodeIfPresent([String].self, forKey: .modelAnswer)
        rubricKind = try container.decodeIfPresent(GeneralPracticeRubricKind.self, forKey: .rubricKind)
        let rawTopics = try container.decodeIfPresent([String].self, forKey: .competencyTopics) ?? [topic]
        competencyTopics = rawTopics.compactMap(InterviewTopic.init(rawValue:))

        if let decodedCriteria = try container.decodeIfPresent([PracticeCompletionCriterion].self, forKey: .completionCriteria) {
            completionCriteria = decodedCriteria
        } else if !completion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completionCriteria = [
                PracticeCompletionCriterion(
                    id: "legacy-completion",
                    requirement: completion,
                    evidencePrompt: artifact
                )
            ]
        } else {
            completionCriteria = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(contentTrack, forKey: .contentTrack)
        try container.encode(competencyTopics.map(\.rawValue), forKey: .competencyTopics)
        try container.encodeIfPresent(rubricKind, forKey: .rubricKind)
        try container.encode(topic, forKey: .topic)
        try container.encode(week, forKey: .week)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(artifact, forKey: .artifact)
        try container.encode(followUps, forKey: .followUps)
        try container.encode(completion, forKey: .completion)
        try container.encode(completionCriteria, forKey: .completionCriteria)
        try container.encodeIfPresent(guide, forKey: .guide)
        try container.encodeIfPresent(modelAnswer, forKey: .modelAnswer)
    }
    func isAvailable(in track: LanguageTrack) -> Bool {
        if let contentTrack { return contentTrack == track }
        return !competencyTopics.contains { $0.languageTrack != nil && $0.languageTrack != track }
    }

    func artifact(for track: LanguageTrack) -> String {
        guard track == .go, kind == "DSA" else { return artifact }
        return artifact.replacingOccurrences(of: "Java solution", with: "Go solution")
    }

    var generalRubric: GeneralPracticeRubric? {
        guard kind == "General" else { return nil }
        return rubricKind?.rubric ?? Self.codingRubric
    }
    fileprivate static let codingRubric = GeneralPracticeRubric(
        signals: [
            "Starts with an explicit contract, constraints, and failure behavior.",
            "Chooses a simple design before optimizing and names its invariants.",
            "Uses targeted tests for boundaries, concurrency, and operational failure.",
            "Explains the production trade-offs, not just the implementation.",
        ],
        strongAnswer: [
            "State assumptions and public behavior before writing code.",
            "Implement the smallest correct version, then explain extension points.",
            "Demonstrate correctness with adversarial tests and observable failure paths.",
        ],
        commonMisses: [
            "Coding before defining null, timeout, ownership, or concurrency semantics.",
            "Claiming thread safety or reliability without tests or a stated contract.",
            "Adding abstractions that do not address a concrete constraint.",
        ],
        scoreGuide: "1 = incomplete or unsafe; 2 = works for the happy path; 3 = clear contract and tested trade-offs; 4 = production-ready judgment with concise communication."
    )

    fileprivate static let designRubric = GeneralPracticeRubric(
        signals: [
            "Discovers requirements, scale, SLOs, and non-goals before selecting components.",
            "Makes data ownership, failure modes, and trade-offs explicit.",
            "Connects the design to delivery, migration, operations, and cost.",
            "Adjusts the proposal when a constraint changes.",
        ],
        strongAnswer: [
            "Frame the problem and success measures, then bound the first design.",
            "Explain the critical read/write path, data model, and operational controls.",
            "Name the riskiest assumption, alternative choices, and validation plan.",
        ],
        commonMisses: [
            "Starting with named technologies rather than requirements.",
            "Describing happy-path architecture without overload, failure, or migration behavior.",
            "Listing trade-offs without making and defending a decision.",
        ],
        scoreGuide: "1 = component list; 2 = plausible architecture; 3 = requirements-led design with explicit trade-offs; 4 = Staff-level strategy, operability, and evolution plan."
    )

    fileprivate static let debugRubric = GeneralPracticeRubric(
        signals: [
            "Forms discriminating hypotheses instead of guessing a root cause.",
            "Orders evidence gathering by impact, reversibility, and information value.",
            "Separates immediate containment from the durable corrective action.",
            "Communicates risk, ownership, and verification clearly.",
        ],
        strongAnswer: [
            "State impact and stabilize the system before making risky changes.",
            "Use telemetry, reproduction, or comparison evidence to narrow hypotheses.",
            "Finish with the invariant, prevention, and signal that proves the repair works.",
        ],
        commonMisses: [
            "Treating a correlation as a root cause.",
            "Proposing a fix without a rollback or verification plan.",
            "Writing a retrospective before explaining immediate containment.",
        ],
        scoreGuide: "1 = guesses at a fix; 2 = identifies a likely cause; 3 = evidence-led mitigation and prevention; 4 = calm incident leadership across technical and organizational boundaries."
    )

    fileprivate static let communicationRubric = GeneralPracticeRubric(
        signals: [
            "Leads with stakes, scope, and the decision rather than implementation detail.",
            "Shows personal influence, disagreement handling, and cross-team leverage.",
            "Uses credible evidence and acknowledges uncertainty or trade-offs.",
            "Ends with a durable organizational or technical change.",
        ],
        strongAnswer: [
            "Give a concise context-action-result-learning narrative.",
            "Name who disagreed, how alignment was built, and what decision was made.",
            "Quantify impact where possible and prepare a specific follow-up example.",
        ],
        commonMisses: [
            "Using ‘we’ throughout without clarifying personal ownership.",
            "Telling a project chronology without a decision, conflict, or result.",
            "Claiming broad influence without evidence of adoption or lasting change.",
        ],
        scoreGuide: "1 = activity summary; 2 = coherent story; 3 = evidence-led Staff narrative; 4 = concise, credible answer that demonstrates organizational leverage."
    )
}

enum Rating: String, Codable, CaseIterable, Identifiable {
    case again, hard, good, easy
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var tintName: String {
        switch self {
        case .again: "red"
        case .hard: "orange"
        case .good: "green"
        case .easy: "blue"
        }
    }
}

struct ReviewRecord: Codable, Hashable {
    var cardID: Int
    var dueAt: Date
    var intervalDays: Int
    var rating: Rating
    var reviews: Int
    var ease: Double
    var lapses: Int
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case cardID, dueAt, intervalDays, rating, reviews, ease, lapses, updatedAt
    }

    init(
        cardID: Int,
        dueAt: Date,
        intervalDays: Int,
        rating: Rating,
        reviews: Int,
        ease: Double = 2.5,
        lapses: Int = 0,
        updatedAt: Date
    ) {
        self.cardID = cardID
        self.dueAt = dueAt
        self.intervalDays = intervalDays
        self.rating = rating
        self.reviews = reviews
        self.ease = ease
        self.lapses = lapses
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardID = try container.decode(Int.self, forKey: .cardID)
        dueAt = try container.decode(Date.self, forKey: .dueAt)
        intervalDays = try container.decode(Int.self, forKey: .intervalDays)
        rating = try container.decode(Rating.self, forKey: .rating)
        reviews = try container.decode(Int.self, forKey: .reviews)
        ease = try container.decodeIfPresent(Double.self, forKey: .ease) ?? 2.5
        lapses = try container.decodeIfPresent(Int.self, forKey: .lapses) ?? 0
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct FlashcardWork: Codable, Hashable {
    var cardID: Int
    var answer: String
    var analysisNotes: String
    var answerDrawing: Data?
    var analysisDrawing: Data?
    var updatedAt: Date
}

enum PracticeStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted = "not-started"
    case attempted
    case completed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notStarted: "Not started"
        case .attempted: "Attempted"
        case .completed: "Completed"
        }
    }
}

struct PracticeRecord: Codable, Hashable {
    var practiceID: String
    var status: PracticeStatus
    var score: Int?
    var notes: String
    var attempts: Int
    var draftArtifact: String
    var draftSatisfiedCriterionIDs: [String]
    var legacyAttemptBaseline: Int
    var nextReviewAt: Date?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case practiceID, status, score, notes, attempts, draftArtifact, draftSatisfiedCriterionIDs, legacyAttemptBaseline, nextReviewAt, updatedAt
    }

    init(
        practiceID: String,
        status: PracticeStatus,
        score: Int? = nil,
        notes: String = "",
        attempts: Int = 0,
        draftArtifact: String = "",
        draftSatisfiedCriterionIDs: [String] = [],
        legacyAttemptBaseline: Int? = nil,
        nextReviewAt: Date? = nil,
        updatedAt: Date
    ) {
        self.practiceID = practiceID
        self.status = status
        self.score = score
        self.notes = notes
        self.attempts = attempts
        self.draftArtifact = draftArtifact
        self.draftSatisfiedCriterionIDs = draftSatisfiedCriterionIDs
        self.legacyAttemptBaseline = legacyAttemptBaseline ?? attempts
        self.nextReviewAt = nextReviewAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        practiceID = try container.decode(String.self, forKey: .practiceID)
        status = try container.decode(PracticeStatus.self, forKey: .status)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        let decodedAttempts = try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        attempts = decodedAttempts
        draftArtifact = try container.decodeIfPresent(String.self, forKey: .draftArtifact) ?? ""
        draftSatisfiedCriterionIDs = try container.decodeIfPresent([String].self, forKey: .draftSatisfiedCriterionIDs) ?? []
        legacyAttemptBaseline = try container.decodeIfPresent(Int.self, forKey: .legacyAttemptBaseline) ?? decodedAttempts
        nextReviewAt = try container.decodeIfPresent(Date.self, forKey: .nextReviewAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct PracticeAttempt: Codable, Identifiable, Hashable {
    var id: String
    var practiceID: String
    var status: PracticeStatus
    var score: Int?
    var notes: String
    var submission: PracticeSubmissionEvidence?
    var completedAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, practiceID, status, score, notes, submission, completedAt, updatedAt
    }

    init(
        id: String,
        practiceID: String,
        status: PracticeStatus,
        score: Int? = nil,
        notes: String = "",
        submission: PracticeSubmissionEvidence? = nil,
        completedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.practiceID = practiceID
        self.status = status
        self.score = score
        self.notes = notes
        self.submission = submission
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        practiceID = try container.decode(String.self, forKey: .practiceID)
        status = try container.decode(PracticeStatus.self, forKey: .status)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        submission = try container.decodeIfPresent(PracticeSubmissionEvidence.self, forKey: .submission)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

struct CareerProfile: Codable, Hashable {
    var pitch: String
    var positioningNotes: String
    var updatedAt: Date
}

protocol CareerRecord: Codable, Identifiable, Hashable {
    var id: String { get set }
    var updatedAt: Date { get set }
    var isDeleted: Bool { get set }
}

struct StaffStory: CareerRecord {
    var id: String
    var title: String
    var signal: String
    var situation: String
    var action: String
    var result: String
    var learning: String
    var updatedAt: Date
    var isDeleted: Bool = false
}

struct TargetCompany: CareerRecord {
    var id: String
    var company: String
    var role: String
    var url: String
    var status: String
    var business: String
    var fit: String
    var engineering: String
    var questions: String
    var nextAction: String
    var nextDate: String
    var updatedAt: Date
    var isDeleted: Bool = false
}

struct Contact: CareerRecord {
    var id: String
    var name: String
    var company: String
    var relationship: String
    var channel: String
    var status: String
    var lastContact: String
    var nextFollowUp: String
    var notes: String
    var updatedAt: Date
    var isDeleted: Bool = false
}

struct JobApplication: CareerRecord {
    var id: String
    var company: String
    var role: String
    var source: String
    var stage: String
    var appliedDate: String
    var nextStep: String
    var nextDate: String
    var round: String
    var interviewDate: String
    var interviewer: String
    var focus: String
    var outcome: String
    var notes: String
    var updatedAt: Date
    var isDeleted: Bool = false
}

enum SyncState: Equatable {
    case notConfigured
    case connecting
    case connected(Date)
    case offline(String)

    var title: String {
        switch self {
        case .notConfigured: "Turso not configured"
        case .connecting: "Connecting…"
        case .connected: "Synced"
        case .offline: "Working locally"
        }
    }
}
