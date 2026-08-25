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
    case topic(InterviewTopic)
    case workspace(WorkspaceSection)

    func resolved(for track: LanguageTrack) -> SidebarDestination {
        switch self {
        case .workspace:
            self
        case .topic(let topic):
            topic.languageTrack == nil || topic.languageTrack == track
                ? self
                : .topic(track.defaultTopic)
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

struct PracticeItem: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let contentTrack: LanguageTrack?
    let topic: String
    let week: Int
    let number: Int
    let title: String
    let prompt: String
    let artifact: String
    let followUps: [String]
    let completion: String
    let guide: PracticeGuide?
    let modelAnswer: [String]?

    func isAvailable(in track: LanguageTrack) -> Bool {
        if let contentTrack { return contentTrack == track }
        guard track == .go, kind != "DSA" else { return true }
        let content = "\(topic) \(title) \(prompt) \(artifact)".localizedLowercase
        return !["java", "jvm", "spring", "completablefuture", "virtual thread"].contains {
            content.contains($0)
        }
    }

    func artifact(for track: LanguageTrack) -> String {
        guard track == .go, kind == "DSA" else { return artifact }
        return artifact.replacingOccurrences(of: "Java solution", with: "Go solution")
    }

    var generalRubric: GeneralPracticeRubric? {
        guard kind == "General" else { return nil }
        let normalizedTitle = title.localizedLowercase

        if normalizedTitle.contains("debug") || normalizedTitle.contains("incident") {
            return Self.debugRubric
        }
        if normalizedTitle.contains("communication")
            || normalizedTitle.contains("narrative")
            || normalizedTitle.contains("behavioral")
            || normalizedTitle.contains("staff") {
            return Self.communicationRubric
        }
        if normalizedTitle.contains("design")
            || normalizedTitle.contains("architecture")
            || normalizedTitle.contains("platform") {
            return Self.designRubric
        }
        return Self.codingRubric
    }

    private static let codingRubric = GeneralPracticeRubric(
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

    private static let designRubric = GeneralPracticeRubric(
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

    private static let debugRubric = GeneralPracticeRubric(
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

    private static let communicationRubric = GeneralPracticeRubric(
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
    var updatedAt: Date
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
    var nextReviewAt: Date?
    var updatedAt: Date
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
