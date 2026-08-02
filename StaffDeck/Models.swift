import Foundation

enum InterviewTopicGroup: String, CaseIterable, Identifiable {
    case foundations = "Foundations"
    case systems = "Systems & Platform"
    case staff = "Staff Practice"

    var id: String { rawValue }
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

    var id: String { rawValue }

    var group: InterviewTopicGroup {
        switch self {
        case .javaFundamentals, .javaAPI, .jvmConcurrency, .spring, .dsa:
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
        }
    }

    static func topics(in group: InterviewTopicGroup) -> [InterviewTopic] {
        allCases.filter { $0.group == group }
    }
}

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case practice = "Practice Lab"
    case career = "Career Hub"
    case settings = "Sync Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .practice: "hammer"
        case .career: "briefcase"
        case .settings: "arrow.triangle.2.circlepath"
        }
    }
}

enum SidebarDestination: Hashable {
    case topic(InterviewTopic)
    case workspace(WorkspaceSection)
}

struct Flashcard: Codable, Identifiable, Hashable {
    let id: Int
    let topic: String
    let question: String
    let testing: String
    let outline: [String]
    let answer: String
    let example: String
    let staffSignal: String
    let followUps: [String]
}

struct PracticeGuide: Codable, Hashable {
    let recognition: String
    let invariant: String
    let anchorProblem: String
    let answer: String
    let complexity: String
    let pitfalls: [String]
}

struct PracticeItem: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let topic: String
    let week: Int
    let number: Int
    let title: String
    let prompt: String
    let artifact: String
    let followUps: [String]
    let completion: String
    let guide: PracticeGuide?
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

struct CachedState: Codable {
    var reviews: [Int: ReviewRecord]
    var flashcardWork: [Int: FlashcardWork]?
    var practice: [String: PracticeRecord]
    var profile: CareerProfile
    var stories: [StaffStory]
    var companies: [TargetCompany]
    var contacts: [Contact]
    var applications: [JobApplication]
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
