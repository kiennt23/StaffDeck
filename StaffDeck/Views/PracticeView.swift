import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    let track: LanguageTrack
    var initialPracticeID: String? = nil
    @State private var kind = "All"
    @State private var topic = "All topics"
    @State private var week = 0
    @State private var progress = "Any progress"
    @State private var query = ""
    @State private var selectedID: String?
    private var topics: [String] {
        ["All topics"] + Set(model.practices.filter { $0.isAvailable(in: track) }.map(\.topic)).sorted()
    }

    private var weeks: [Int] {
        Set(model.practices.map(\.week)).sorted()
    }

    private var filtered: [PracticeItem] {
        model.practices.filter { item in
            guard item.isAvailable(in: track) else { return false }
            guard kind == "All" || item.kind == kind else { return false }
            guard topic == "All topics" || item.topic == topic else { return false }
            guard week == 0 || item.week == week else { return false }
            guard query.isEmpty || "\(item.title) \(item.prompt) \(item.topic)"
                .localizedCaseInsensitiveContains(query) else { return false }

            let record = model.practiceRecords[item.id]
            switch progress {
            case "Not started":
                return (record?.status ?? .notStarted) == .notStarted
            case "Attempted":
                return record?.status == .attempted
            case "Completed":
                return record?.status == .completed
            case "Re-solve due":
                return record?.nextReviewAt.map { $0 <= Date() } == true
            default:
                return true
            }
        }
        .sorted {
            ($0.week, $0.number) < ($1.week, $1.number)
        }
    }

    var body: some View {
        Group {
            #if os(macOS)
            GeometryReader { proxy in
                practiceContent
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .top
                    )
            }
            #else
            practiceContent
            #endif
        }
        .navigationTitle("Practice Lab")
        .onAppear {
            if let targetID = initialPracticeID {
                kind = "All"
                topic = "All topics"
                week = 0
                progress = "Any progress"
                query = ""
                selectedID = targetID
            } else if selectedID == nil {
                selectedID = filtered.first?.id
            }
        }
        .onChange(of: filtered.map(\.id)) { _, ids in
            if selectedID.map({ ids.contains($0) }) != true {
                selectedID = ids.first
            }
        }
    }

    @ViewBuilder
    private var practiceContent: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            practiceHeader
            practiceFilters
            practiceWorkspace
        }
        .background(Color.staffPaper)
        #else
        ScrollView {
            VStack(spacing: 0) {
                practiceHeader
                practiceFilters
                practiceWorkspace
            }
        }
        .background(Color.staffPaper)
        #endif
    }

    private var practiceHeader: some View {
        HStack(alignment: .bottom) {
            SectionHeader(
                eyebrow: "Deliberate practice workspace",
                title: "Turn plans into proof.",
                subtitle: "Record a first attempt, score it, and keep the next re-solve visible."
            )
            Spacer()
            summary
        }
        .padding(24)
    }

    private var practiceFilters: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                kindPicker
                searchField
                topicPicker
                weekPicker
                progressPicker
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    kindPicker
                    searchField
                }
                HStack(spacing: 10) {
                    topicPicker
                    weekPicker
                    progressPicker
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var practiceWorkspace: some View {
        VStack(spacing: 16) {
            practiceExerciseRail
            practiceDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var kindPicker: some View {
        Picker("Kind", selection: $kind) {
            Text("All practice").tag("All")
            Text("General").tag("General")
            Text("DSA").tag("DSA")
        }
        .pickerStyle(.segmented)
        .frame(width: 280)
    }

    private var searchField: some View {
        TextField("Search exercises", text: $query)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 180)
    }

    private var topicPicker: some View {
        Picker("Topic", selection: $topic) {
            ForEach(topics, id: \.self, content: Text.init)
        }
        .frame(width: 200)
    }

    private var weekPicker: some View {
        Picker("Week", selection: $week) {
            Text("All weeks").tag(0)
            ForEach(weeks, id: \.self) { value in
                Text("Week \(value)").tag(value)
            }
        }
        .frame(width: 140)
    }

    private var progressPicker: some View {
        Picker("Progress", selection: $progress) {
            Text("Any progress").tag("Any progress")
            Text("Not started").tag("Not started")
            Text("Attempted").tag("Attempted")
            Text("Completed").tag("Completed")
            Text("Re-solve due").tag("Re-solve due")
        }
        .frame(width: 170)
    }

    private var practiceExerciseRail: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(filtered.count) exercises")
                    .font(.headline)
                Text("Select an exercise to work on")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(kind)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button {
                    selectAdjacentExercise(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(selectedExerciseIndex <= 0)
                .help("Previous exercise")

                Text(exercisePosition)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 46)

                Button {
                    selectAdjacentExercise(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(
                    selectedExerciseIndex < 0
                        || selectedExerciseIndex >= filtered.count - 1
                )
                .help("Next exercise")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        ForEach(filtered) { item in
                            Button {
                                selectedID = item.id
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text("#\(item.number) · W\(item.week)")
                                        Spacer()
                                        if let record = model.practiceRecords[item.id] {
                                            Image(systemName: statusIcon(record.status))
                                                .accessibilityLabel(record.status.title)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    Text(item.title)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(10)
                                .frame(width: 190, height: 74, alignment: .topLeading)
                                .background(
                                    selectedID == item.id
                                        ? Color.staffGreen.opacity(0.18)
                                        : Color.staffPaper,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            selectedID == item.id
                                                ? Color.staffGreen
                                                : Color.staffBorder,
                                            lineWidth: selectedID == item.id ? 2 : 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                    .padding(10)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selectedID) { _, id in
                    guard let id else { return }
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .frame(height: 94)
        }
        .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.staffBorder)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var selectedItem: PracticeItem? {
        model.practices.first { $0.id == selectedID } ?? filtered.first
    }

    private var selectedExerciseIndex: Int {
        guard let selectedID else { return filtered.isEmpty ? -1 : 0 }
        return filtered.firstIndex { $0.id == selectedID } ?? -1
    }

    private var exercisePosition: String {
        guard selectedExerciseIndex >= 0 else { return "0 / \(filtered.count)" }
        return "\(selectedExerciseIndex + 1) / \(filtered.count)"
    }

    private func selectAdjacentExercise(_ offset: Int) {
        let next = selectedExerciseIndex + offset
        guard filtered.indices.contains(next) else { return }
        selectedID = filtered[next].id
    }

    private func statusIcon(_ status: PracticeStatus) -> String {
        switch status {
        case .notStarted: "circle"
        case .attempted: "circle.lefthalf.filled"
        case .completed: "checkmark.circle.fill"
        }
    }

    @ViewBuilder
    private var practiceDetail: some View {
        if let item = selectedItem {
            PracticeDetail(
                item: item,
                record: model.practiceRecords[item.id],
                track: track,
                scrollsInternally: usesInternalDetailScroll
            )
            .id(item.id)
        } else {
            EmptyState(
                title: "Choose a practice",
                message: "Select an exercise to record an attempt, notes, and score."
            )
        }
    }

    private var usesInternalDetailScroll: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    private var summary: some View {
        let completed = model.practiceRecords.values.filter { $0.status == .completed }.count
        let due = model.practiceRecords.values.filter {
            ($0.nextReviewAt ?? .distantFuture) <= Date()
        }.count
        return HStack(spacing: 22) {
            summaryValue(completed, "completed")
            summaryValue(due, "re-solves due")
        }
    }

    private func summaryValue(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .trailing) {
            Text("\(value)")
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private enum PracticeSubmissionState: Equatable {
    case idle
    case validationFailure(String)
    case submitting
    case submitted
}

private struct PracticeDetail: View {
    @EnvironmentObject private var model: AppModel
    let item: PracticeItem
    let record: PracticeRecord?
    let track: LanguageTrack
    let scrollsInternally: Bool
    @State private var score: Int?
    @State private var notes: String
    @State private var draftArtifact: String
    @State private var satisfiedCriterionIDs: Set<String>
    @State private var submissionState = PracticeSubmissionState.idle
    @State private var isDirty = false
    @State private var guideOpen = false
    @State private var modelAnswerOpen = false
    @AccessibilityFocusState private var validationFocused: Bool

    init(item: PracticeItem, record: PracticeRecord?, track: LanguageTrack, scrollsInternally: Bool) {
        self.item = item
        self.record = record
        self.track = track
        self.scrollsInternally = scrollsInternally
        let validCriterionIDs = Set(item.completionCriteria.map(\.id))
        let selectedCriterionIDs = Set(
            (record?.draftSatisfiedCriterionIDs ?? []).filter(validCriterionIDs.contains)
        )
        _score = State(initialValue: record?.score)
        _notes = State(initialValue: record?.notes ?? "")
        _draftArtifact = State(initialValue: record?.draftArtifact ?? "")
        _satisfiedCriterionIDs = State(initialValue: selectedCriterionIDs)
    }

    @ViewBuilder
    var body: some View {
        if scrollsInternally {
            ScrollView {
                detailContent
            }
            .background(Color.staffPaper)
            .onChange(of: record) { _, nextRecord in
                refreshLocalState(from: nextRecord)
            }
        } else {
            detailContent
                .background(Color.staffPaper)
                .onChange(of: record) { _, nextRecord in
                    refreshLocalState(from: nextRecord)
                }
        }
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(item.kind)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.staffLime.opacity(0.35), in: Capsule())
                Text("Week \(item.week) · Exercise \(item.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.title)
                .font(.system(.title, design: .serif, weight: .medium))
            assignment("Assignment", item.prompt)
            assignment("Required evidence", item.artifact(for: track))

            attemptEditor

            if let rubric = item.generalRubric, persistedStatus != .notStarted {
                GeneralPracticeRubricView(rubric: rubric)
            }

            coachingContent

            assignment("Completion gate", item.completion)
            if !item.followUps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("INTERVIEWER FOLLOW-UPS")
                        .font(.caption.bold())
                        .foregroundStyle(Color.staffGreen)
                    ForEach(item.followUps, id: \.self) {
                        Label($0, systemImage: "questionmark.bubble")
                    }
                }
            }
        }
        .padding(26)
        .frame(maxWidth: 850, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var attemptEditor: some View {
        GroupBox("Attempt evidence") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Status") {
                    Label(persistedStatus.title, systemImage: statusIcon)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Completion criteria")
                        .font(.headline)
                    ForEach(item.completionCriteria) { criterion in
                        criterionToggle(criterion)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Artifact evidence")
                        .font(.headline)
                    PencilCapableTextEditor(
                        text: artifactBinding,
                        minHeight: 160,
                        prompt: "Paste the artifact or describe the evidence you produced…"
                    )
                    .accessibilityLabel("Artifact evidence")
                }

                Picker("Score", selection: scoreBinding) {
                    Text("Not scored").tag(Int?.none)
                    ForEach(1...4, id: \.self) { Text("\($0) / 4").tag(Int?.some($0)) }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    PencilCapableTextEditor(
                        text: notesBinding,
                        minHeight: 130,
                        prompt: "Attempt notes, trade-offs, and what to improve…"
                    )
                    .accessibilityLabel("Attempt notes")
                }

                submissionFeedback
                submissionActions
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var submissionFeedback: some View {
        switch submissionState {
        case .validationFailure(let message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($validationFocused)
        case .submitted:
            Label("Attempt submitted", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Color.staffGreen)
        case .idle, .submitting:
            EmptyView()
        }
    }

    private var submissionActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                saveDraftButton
                Spacer()
                submitAttemptButton
            }
            VStack(alignment: .leading, spacing: 12) {
                submitAttemptButton
                    .frame(maxWidth: .infinity, alignment: .leading)
                saveDraftButton
            }
        }
    }

    private var saveDraftButton: some View {
        Button("Save draft", action: saveDraft)
            .buttonStyle(.bordered)
            .disabled(!isDirty || isSubmitting)
            #if os(iOS)
            .frame(minHeight: 44)
            #endif
    }

    private var submitAttemptButton: some View {
        Button(action: submitAttempt) {
            if isSubmitting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Submitting…")
                }
            } else {
                Text("Submit attempt")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.staffGreen)
        .disabled(isSubmitting)
        #if os(iOS)
        .frame(minHeight: 44)
        #endif
    }

    @ViewBuilder
    private var coachingContent: some View {
        if coachingUnlocked {
            if let guide = item.guide {
                DisclosureGroup("Worked guide", isExpanded: $guideOpen) {
                    VStack(alignment: .leading, spacing: 12) {
                        assignment("Recognition cues", guide.recognition)
                        assignment("Core invariant", guide.invariant)
                        assignment("Anchor problem", guide.anchorProblem)
                        assignment("Answer guide", guide.answer)
                        assignment("Complexity", guide.complexity)
                        if !guide.pitfalls.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PITFALLS")
                                    .font(.caption.bold())
                                    .tracking(1)
                                    .foregroundStyle(Color.staffCoral)
                                ForEach(guide.pitfalls, id: \.self) { pitfall in
                                    Label(pitfall, systemImage: "exclamationmark.triangle")
                                        .lineSpacing(3)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }

            if let modelAnswer = item.modelAnswer, !modelAnswer.isEmpty {
                DisclosureGroup(modelAnswerTitle, isExpanded: $modelAnswerOpen) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(modelAnswer, id: \.self) { point in
                            Label(point, systemImage: "checkmark.circle")
                                .lineSpacing(3)
                        }
                    }
                    .padding(.top, 10)
                }
            }
        } else {
            if item.guide != nil {
                lockedCoachingGroup("Worked guide")
            }
            if let modelAnswer = item.modelAnswer, !modelAnswer.isEmpty {
                lockedCoachingGroup(modelAnswerTitle)
            }
        }
    }

    private var persistedStatus: PracticeStatus {
        record?.status ?? .notStarted
    }

    private var statusIcon: String {
        switch persistedStatus {
        case .notStarted: "circle"
        case .attempted: "circle.lefthalf.filled"
        case .completed: "checkmark.circle.fill"
        }
    }

    private var modelAnswerTitle: String {
        item.kind == "DSA" ? "This drill's approach" : "Model answer"
    }

    private var coachingUnlocked: Bool {
        model.hasSubmittedEvidence(for: item.id)
    }

    private var isSubmitting: Bool {
        submissionState == .submitting
    }

    private var orderedSatisfiedCriterionIDs: [String] {
        item.completionCriteria.map(\.id).filter(satisfiedCriterionIDs.contains)
    }

    private var scoreBinding: Binding<Int?> {
        Binding(
            get: { score },
            set: { nextScore in
                guard score != nextScore else { return }
                score = nextScore
                markDirty()
            }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { notes },
            set: { nextNotes in
                guard notes != nextNotes else { return }
                notes = nextNotes
                markDirty()
            }
        )
    }

    private var artifactBinding: Binding<String> {
        Binding(
            get: { draftArtifact },
            set: { nextArtifact in
                guard draftArtifact != nextArtifact else { return }
                draftArtifact = nextArtifact
                markDirty()
            }
        )
    }

    private func criterionToggle(_ criterion: PracticeCompletionCriterion) -> some View {
        let isSelected = satisfiedCriterionIDs.contains(criterion.id)
        return Toggle(isOn: criterionBinding(for: criterion.id)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(criterion.requirement)
                Text(criterion.evidencePrompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(criterion.requirement)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(criterion.evidencePrompt)
        #if os(iOS)
        .frame(minHeight: 44)
        #endif
    }

    private func criterionBinding(for criterionID: String) -> Binding<Bool> {
        Binding(
            get: { satisfiedCriterionIDs.contains(criterionID) },
            set: { isSelected in
                var nextCriterionIDs = satisfiedCriterionIDs
                if isSelected {
                    nextCriterionIDs.insert(criterionID)
                } else {
                    nextCriterionIDs.remove(criterionID)
                }
                guard nextCriterionIDs != satisfiedCriterionIDs else { return }
                satisfiedCriterionIDs = nextCriterionIDs
                markDirty()
            }
        )
    }

    private func lockedCoachingGroup(_ title: String) -> some View {
        GroupBox(title) {
            Label("Submit evidence to unlock", systemImage: "lock.fill")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). Submit evidence to unlock")
    }

    private func assignment(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.bold())
                .tracking(1)
                .foregroundStyle(Color.staffGreen)
            Text(body)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.staffSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
    }

    private func markDirty() {
        isDirty = true
        validationFocused = false
        if !isSubmitting {
            submissionState = .idle
        }
    }

    private func refreshLocalState(from nextRecord: PracticeRecord?) {
        guard !isDirty else { return }
        let validCriterionIDs = Set(item.completionCriteria.map(\.id))
        score = nextRecord?.score
        notes = nextRecord?.notes ?? ""
        draftArtifact = nextRecord?.draftArtifact ?? ""
        satisfiedCriterionIDs = Set(
            (nextRecord?.draftSatisfiedCriterionIDs ?? []).filter(validCriterionIDs.contains)
        )
    }

    private func saveDraft() {
        model.savePracticeDraft(
            itemID: item.id,
            status: persistedStatus,
            score: score,
            notes: notes,
            artifact: draftArtifact,
            satisfiedCriterionIDs: orderedSatisfiedCriterionIDs
        )
        isDirty = false
        submissionState = .idle
        validationFocused = false
    }

    private func submitAttempt() {
        submissionState = .submitting
        validationFocused = false
        do {
            try model.submitPracticeAttempt(
                itemID: item.id,
                score: score,
                notes: notes,
                artifact: draftArtifact,
                satisfiedCriterionIDs: orderedSatisfiedCriterionIDs
            )
            isDirty = false
            submissionState = .submitted
            AccessibilityNotification.Announcement("Attempt submitted").post()
        } catch {
            submissionState = .validationFailure(error.localizedDescription)
            Task { @MainActor in
                validationFocused = true
            }
        }
    }
}

private struct GeneralPracticeRubricView: View {
    let rubric: GeneralPracticeRubric

    var body: some View {
        GroupBox("Staff-level self-review") {
            VStack(alignment: .leading, spacing: 16) {
                rubricSection("Signals to demonstrate", items: rubric.signals)
                rubricSection("Strong-answer structure", items: rubric.strongAnswer)
                rubricSection("Common misses", items: rubric.commonMisses)
                Text(rubric.scoreGuide)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private func rubricSection(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption.bold())
                .tracking(1)
                .foregroundStyle(Color.staffGreen)
            ForEach(items, id: \.self) {
                Label($0, systemImage: "checkmark.circle")
                    .font(.callout)
            }
        }
    }
}
