import Foundation

struct CachedState: Codable {
    var reviews: [Int: ReviewRecord]
    var flashcardWork: [Int: FlashcardWork]
    var practice: [String: PracticeRecord]
    var practiceAttempts: [String: [PracticeAttempt]]
    var profile: CareerProfile
    var stories: [StaffStory]
    var companies: [TargetCompany]
    var contacts: [Contact]
    var applications: [JobApplication]
    var pendingMutations: [SyncEnvelope]

    init(
        reviews: [Int: ReviewRecord],
        flashcardWork: [Int: FlashcardWork],
        practice: [String: PracticeRecord],
        practiceAttempts: [String: [PracticeAttempt]] = [:],
        profile: CareerProfile,
        stories: [StaffStory],
        companies: [TargetCompany],
        contacts: [Contact],
        applications: [JobApplication],
        pendingMutations: [SyncEnvelope] = []
    ) {
        self.reviews = reviews
        self.flashcardWork = flashcardWork
        self.practice = practice
        self.practiceAttempts = practiceAttempts
        self.profile = profile
        self.stories = stories
        self.companies = companies
        self.contacts = contacts
        self.applications = applications
        self.pendingMutations = pendingMutations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reviews = try container.decode([Int: ReviewRecord].self, forKey: .reviews)
        flashcardWork = try container.decodeIfPresent(
            [Int: FlashcardWork].self,
            forKey: .flashcardWork
        ) ?? [:]
        practice = try container.decode([String: PracticeRecord].self, forKey: .practice)
        practiceAttempts = try container.decodeIfPresent(
            [String: [PracticeAttempt]].self,
            forKey: .practiceAttempts
        ) ?? [:]
        profile = try container.decode(CareerProfile.self, forKey: .profile)
        stories = try container.decode([StaffStory].self, forKey: .stories)
        companies = try container.decode([TargetCompany].self, forKey: .companies)
        contacts = try container.decode([Contact].self, forKey: .contacts)
        applications = try container.decode([JobApplication].self, forKey: .applications)
        pendingMutations = try container.decodeIfPresent(
            [SyncEnvelope].self,
            forKey: .pendingMutations
        ) ?? []
    }
}
