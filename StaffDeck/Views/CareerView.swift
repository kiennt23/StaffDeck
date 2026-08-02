import SwiftUI

struct CareerView: View {
    @State private var tab = "Positioning"
    private let tabs = ["Positioning", "Stories", "Companies", "Networking", "Applications"]

    var body: some View {
        #if os(macOS)
        GeometryReader { proxy in
            careerContent
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .top
                )
        }
        .navigationTitle("Career Hub")
        #else
        careerContent
            .navigationTitle("Career Hub")
        #endif
    }

    private var careerContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                SectionHeader(
                    eyebrow: "Career operating system",
                    title: "Turn experience into signal.",
                    subtitle: "Shape the narrative, collect evidence-rich stories, and keep every opportunity moving."
                )
                Spacer()
            }
            .padding(24)

            Picker("Career tool", selection: $tab) {
                ForEach(tabs, id: \.self, content: Text.init)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            Group {
                switch tab {
                case "Stories": StoriesView()
                case "Companies": CompaniesView()
                case "Networking": ContactsView()
                case "Applications": ApplicationsView()
                default: PositioningView()
                }
            }
        }
        .background(Color.staffPaper)
    }
}

private struct PositioningView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pitch = ""
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your Staff-level throughline")
                    .font(.system(.title, design: .serif, weight: .medium))
                LabeledTextArea(
                    title: "Working positioning statement",
                    text: $pitch,
                    height: 140
                )
                Text("Use this as raw material for the résumé summary, recruiter introduction, and “tell me about yourself”—not as a script.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230))], spacing: 14) {
                    theme(
                        "Lead with scope, not title",
                        "Position Staff as scope already exercised: shared platform ownership, cross-team migration, and business-critical decisions."
                    )
                    theme(
                        "Use authorization as the signature",
                        "Anchor architecture, security, platform, and influence conversations in the OpenFGA story and its measurable latency."
                    )
                    theme(
                        "Bridge application and platform",
                        "Frame Java services, Kafka, micro-frontends, delivery tooling, and multi-cloud work as boundary-spanning judgment."
                    )
                    theme(
                        "Make Java recency explicit",
                        "Connect current Java practice to durable distributed-systems reasoning and name what you would modernize today."
                    )
                }

                LabeledTextArea(
                    title: "Positioning notes",
                    text: $notes,
                    prompt: "Claims to validate, metrics to recover, résumé edits…",
                    height: 150
                )
                Button("Save positioning") {
                    model.saveProfile(
                        CareerProfile(
                            pitch: pitch,
                            positioningNotes: notes,
                            updatedAt: model.profile.updatedAt
                        )
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.staffGreen)
            }
            .padding(26)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            pitch = model.profile.pitch
            notes = model.profile.positioningNotes
        }
    }

    private func theme(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct StoriesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: StaffStory?
    @State private var query = ""
    @State private var filter = "All stories"

    private var visible: [StaffStory] {
        model.stories.filter {
            !$0.isDeleted
                && (query.isEmpty || [
                    $0.title, $0.signal, $0.situation, $0.action, $0.result, $0.learning,
                ].joined(separator: " ").localizedCaseInsensitiveContains(query))
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(spacing: 12) {
            CareerFilterBar(
                query: $query,
                selection: $filter,
                placeholder: "Search stories",
                filterTitle: "Stories",
                options: ["All stories"]
            )
            CareerRecordList(
                title: "\(visible.count) Staff stories",
                isEmpty: visible.isEmpty,
                emptyTitle: "Build your story bank",
                emptyMessage: "Capture a Staff decision with stakes, influence, evidence, and learning.",
                add: {
                    editing = StaffStory(
                        id: UUID().uuidString,
                        title: "New Staff story",
                        signal: "",
                        situation: "",
                        action: "",
                        result: "",
                        learning: "",
                        updatedAt: .distantPast
                    )
                }
            ) {
                ForEach(visible) { story in
                    Button { editing = story } label: {
                        recordRow(story.title, detail: story.signal, icon: "quote.bubble")
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) { model.deleteStory(story) }
                    }
                }
            }
        }
        .sheet(item: $editing) { story in
            StoryEditor(story: story) { model.saveStory($0) }
        }
    }
}

private struct StoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var story: StaffStory
    let save: (StaffStory) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Story identity") {
                    TextField("Title", text: $story.title)
                    TextField("Signals demonstrated", text: $story.signal)
                }
                Section("STAR-L evidence") {
                    LabeledTextArea(title: "Situation and stakes", text: $story.situation)
                    LabeledTextArea(title: "Your decisions and actions", text: $story.action)
                    LabeledTextArea(title: "Results and evidence", text: $story.result)
                    LabeledTextArea(title: "Learning and durable change", text: $story.learning)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(story.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(story); dismiss() }
                        .disabled(story.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 620)
    }
}

private struct CompaniesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: TargetCompany?
    @State private var query = ""
    @State private var status = "All statuses"

    private var visible: [TargetCompany] {
        model.companies.filter {
            !$0.isDeleted
                && (status == "All statuses" || $0.status == status)
                && (query.isEmpty || [
                    $0.company, $0.role, $0.status, $0.business, $0.fit, $0.engineering,
                ].joined(separator: " ").localizedCaseInsensitiveContains(query))
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var statuses: [String] {
        ["All statuses"] + Set(
            model.companies.filter { !$0.isDeleted }.map(\.status).filter { !$0.isEmpty }
        ).sorted()
    }

    var body: some View {
        VStack(spacing: 12) {
            CareerFilterBar(
                query: $query,
                selection: $status,
                placeholder: "Search companies",
                filterTitle: "Status",
                options: statuses
            )
            CareerRecordList(
                title: "\(visible.count) target companies",
                isEmpty: visible.isEmpty,
                emptyTitle: "No target companies found",
                emptyMessage: "Adjust the filters or add a role where your evidence has a clear fit.",
                add: {
                    editing = TargetCompany(
                        id: UUID().uuidString,
                        company: "New company",
                        role: "Staff Software Engineer",
                        url: "",
                        status: "Researching",
                        business: "",
                        fit: "",
                        engineering: "",
                        questions: "",
                        nextAction: "",
                        nextDate: "",
                        updatedAt: .distantPast
                    )
                }
            ) {
                ForEach(visible) { company in
                    Button { editing = company } label: {
                        recordRow(
                            company.company,
                            detail: "\(company.status) · \(company.role)",
                            icon: "building.2"
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) { model.deleteCompany(company) }
                    }
                }
            }
        }
        .sheet(item: $editing) { company in
            CompanyEditor(company: company) { model.saveCompany($0) }
        }
    }
}

private struct CompanyEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var company: TargetCompany
    let save: (TargetCompany) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    TextField("Company", text: $company.company)
                    TextField("Role", text: $company.role)
                    TextField("Research status", text: $company.status)
                    TextField("Role or company URL", text: $company.url)
                }
                Section("Research") {
                    LabeledTextArea(title: "Business, customers, and priorities", text: $company.business)
                    LabeledTextArea(title: "Why your evidence fits", text: $company.fit)
                    LabeledTextArea(title: "Engineering signals and constraints", text: $company.engineering)
                    LabeledTextArea(title: "Questions that test the opportunity", text: $company.questions)
                }
                Section("Next move") {
                    TextField("Next research action", text: $company.nextAction)
                    TextField("Target date (YYYY-MM-DD)", text: $company.nextDate)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(company.company)
            .editorToolbar { save(company); dismiss() } cancel: { dismiss() }
        }
        .frame(minWidth: 560, minHeight: 660)
    }
}

private struct ContactsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: Contact?
    @State private var query = ""
    @State private var status = "All statuses"

    private var visible: [Contact] {
        model.contacts.filter {
            !$0.isDeleted
                && (status == "All statuses" || $0.status == status)
                && (query.isEmpty || [
                    $0.name, $0.company, $0.relationship, $0.channel, $0.status, $0.notes,
                ].joined(separator: " ").localizedCaseInsensitiveContains(query))
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var statuses: [String] {
        ["All statuses"] + Set(
            model.contacts.filter { !$0.isDeleted }.map(\.status).filter { !$0.isEmpty }
        ).sorted()
    }

    var body: some View {
        VStack(spacing: 12) {
            CareerFilterBar(
                query: $query,
                selection: $status,
                placeholder: "Search contacts",
                filterTitle: "Status",
                options: statuses
            )
            CareerRecordList(
                title: "\(visible.count) contacts",
                isEmpty: visible.isEmpty,
                emptyTitle: "No contacts found",
                emptyMessage: "Adjust the filters or add someone for a useful next conversation.",
                add: {
                    editing = Contact(
                        id: UUID().uuidString,
                        name: "New contact",
                        company: "",
                        relationship: "",
                        channel: "LinkedIn",
                        status: "To contact",
                        lastContact: "",
                        nextFollowUp: "",
                        notes: "",
                        updatedAt: .distantPast
                    )
                }
            ) {
                ForEach(visible) { contact in
                    Button { editing = contact } label: {
                        recordRow(
                            contact.name,
                            detail: "\(contact.status) · \(contact.company.isEmpty ? "No company" : contact.company)",
                            icon: "person.2"
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) { model.deleteContact(contact) }
                    }
                }
            }
        }
        .sheet(item: $editing) { contact in
            ContactEditor(contact: contact) { model.saveContact($0) }
        }
    }
}

private struct ContactEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var contact: Contact
    let save: (Contact) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Name", text: $contact.name)
                    TextField("Company", text: $contact.company)
                    TextField("Relationship or context", text: $contact.relationship)
                    TextField("Channel", text: $contact.channel)
                    TextField("Status", text: $contact.status)
                }
                Section("Follow-up") {
                    TextField("Last contact (YYYY-MM-DD)", text: $contact.lastContact)
                    TextField("Next follow-up (YYYY-MM-DD)", text: $contact.nextFollowUp)
                    LabeledTextArea(
                        title: "Conversation notes and a useful next touch",
                        text: $contact.notes
                    )
                }
            }
            .formStyle(.grouped)
            .navigationTitle(contact.name)
            .editorToolbar { save(contact); dismiss() } cancel: { dismiss() }
        }
        .frame(minWidth: 540, minHeight: 590)
    }
}

private struct ApplicationsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editing: JobApplication?
    @State private var query = ""
    @State private var stage = "All stages"

    private var visible: [JobApplication] {
        model.applications.filter {
            !$0.isDeleted
                && (stage == "All stages" || $0.stage == stage)
                && (query.isEmpty || [
                    $0.company, $0.role, $0.source, $0.stage, $0.round, $0.interviewer,
                    $0.focus, $0.outcome, $0.notes,
                ].joined(separator: " ").localizedCaseInsensitiveContains(query))
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var stages: [String] {
        ["All stages"] + Set(
            model.applications.filter { !$0.isDeleted }.map(\.stage).filter { !$0.isEmpty }
        ).sorted()
    }

    var body: some View {
        VStack(spacing: 12) {
            CareerFilterBar(
                query: $query,
                selection: $stage,
                placeholder: "Search applications",
                filterTitle: "Stage",
                options: stages
            )
            CareerRecordList(
                title: "\(visible.count) applications",
                isEmpty: visible.isEmpty,
                emptyTitle: "No applications found",
                emptyMessage: "Adjust the filters or add an opportunity to track.",
                add: {
                    editing = JobApplication(
                        id: UUID().uuidString,
                        company: "New company",
                        role: "Staff Software Engineer",
                        source: "",
                        stage: "Interested",
                        appliedDate: "",
                        nextStep: "",
                        nextDate: "",
                        round: "",
                        interviewDate: "",
                        interviewer: "",
                        focus: "",
                        outcome: "",
                        notes: "",
                        updatedAt: .distantPast
                    )
                }
            ) {
                ForEach(visible) { application in
                    Button { editing = application } label: {
                        recordRow(
                            "\(application.company) — \(application.role)",
                            detail: "\(application.stage) · \(application.round.isEmpty ? "No round" : application.round)",
                            icon: "briefcase"
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) { model.deleteApplication(application) }
                    }
                }
            }
        }
        .sheet(item: $editing) { application in
            ApplicationEditor(application: application) { model.saveApplication($0) }
        }
    }
}

private struct ApplicationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var application: JobApplication
    let save: (JobApplication) -> Void
    private let stages = [
        "Interested", "Researching", "Networking", "Applied", "Recruiter interview",
        "Technical interview", "Onsite / loop", "Reference check", "Offer", "Rejected",
        "Withdrawn",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Opportunity") {
                    TextField("Company", text: $application.company)
                    TextField("Role", text: $application.role)
                    Picker("Stage", selection: $application.stage) {
                        ForEach(stages, id: \.self, content: Text.init)
                    }
                    TextField("Source or referral", text: $application.source)
                    TextField("Applied date (YYYY-MM-DD)", text: $application.appliedDate)
                }
                Section("Next step") {
                    TextField("Next action", text: $application.nextStep)
                    TextField("Next-action date (YYYY-MM-DD)", text: $application.nextDate)
                }
                Section("Current interview") {
                    TextField("Round", text: $application.round)
                    TextField("Interview date and time", text: $application.interviewDate)
                    TextField("Interviewer", text: $application.interviewer)
                    LabeledTextArea(title: "Focus and preparation", text: $application.focus)
                    LabeledTextArea(title: "Outcome and follow-up", text: $application.outcome)
                }
                Section("Notes") {
                    LabeledTextArea(title: "Opportunity notes", text: $application.notes)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(application.company)
            .editorToolbar { save(application); dismiss() } cancel: { dismiss() }
        }
        .frame(minWidth: 580, minHeight: 700)
    }
}

private struct CareerFilterBar: View {
    @Binding var query: String
    @Binding var selection: String
    let placeholder: String
    let filterTitle: String
    let options: [String]

    private var hasActiveFilters: Bool {
        !query.isEmpty || selection != (options.first ?? "")
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $query)
                .textFieldStyle(.roundedBorder)

            if options.count > 1 {
                Picker(filterTitle, selection: $selection) {
                    ForEach(options, id: \.self, content: Text.init)
                }
                .frame(width: 220)
            }

            Button("Clear filters") {
                query = ""
                selection = options.first ?? ""
            }
            .buttonStyle(.borderless)
            .frame(width: 88, alignment: .trailing)
            .opacity(hasActiveFilters ? 1 : 0)
            .allowsHitTesting(hasActiveFilters)
            .accessibilityHidden(!hasActiveFilters)
        }
        .padding(.horizontal, 24)
    }
}

private struct CareerRecordList<Content: View>: View {
    let title: String
    let isEmpty: Bool
    let emptyTitle: String
    let emptyMessage: String
    let add: () -> Void
    @ViewBuilder let content: Content

    init(
        title: String,
        isEmpty: Bool,
        emptyTitle: String,
        emptyMessage: String,
        add: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isEmpty = isEmpty
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.add = add
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Add", systemImage: "plus", action: add)
                    .buttonStyle(.borderedProminent)
                    .tint(.staffGreen)
            }

            List {
                content
            }
            .scrollContentBackground(.hidden)
            .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.staffBorder)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                if isEmpty {
                    EmptyState(title: emptyTitle, message: emptyMessage)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

private struct LabeledTextArea: View {
    let title: String
    @Binding var text: String
    var prompt = ""
    var height: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            PencilCapableTextEditor(
                text: $text,
                minHeight: height,
                prompt: prompt
            )
        }
    }
}

@ViewBuilder
private func recordRow(_ title: String, detail: String, icon: String) -> some View {
    HStack(spacing: 14) {
        Image(systemName: icon)
            .foregroundStyle(Color.staffGreen)
            .frame(width: 34, height: 34)
            .background(Color.staffLime.opacity(0.25), in: RoundedRectangle(cornerRadius: 9))
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(detail.isEmpty ? "Add evidence and context" : detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 7)
    .contentShape(Rectangle())
}

private extension View {
    func editorToolbar(save: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
    }
}
