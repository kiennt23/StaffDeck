import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var kind = "All"
    @State private var topic = "All topics"
    @State private var week = 0
    @State private var progress = "Any progress"
    @State private var query = ""
    @State private var selectedID: String?

    private var topics: [String] {
        ["All topics"] + Set(model.practices.map(\.topic)).sorted()
    }

    private var weeks: [Int] {
        Set(model.practices.map(\.week)).sorted()
    }

    private var filtered: [PracticeItem] {
        model.practices.filter { item in
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
            if selectedID == nil { selectedID = filtered.first?.id }
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

private struct PracticeDetail: View {
    @EnvironmentObject private var model: AppModel
    let item: PracticeItem
    let scrollsInternally: Bool
    @State private var status: PracticeStatus
    @State private var score: Int?
    @State private var notes: String
    @State private var guideOpen = false

    init(item: PracticeItem, record: PracticeRecord?, scrollsInternally: Bool) {
        self.item = item
        self.scrollsInternally = scrollsInternally
        _status = State(initialValue: record?.status ?? .notStarted)
        _score = State(initialValue: record?.score)
        _notes = State(initialValue: record?.notes ?? "")
    }

    @ViewBuilder
    var body: some View {
        if scrollsInternally {
            ScrollView {
                detailContent
            }
            .background(Color.staffPaper)
        } else {
            detailContent
                .background(Color.staffPaper)
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
                assignment("Required evidence", item.artifact)

                if let guide = item.guide {
                    DisclosureGroup("Worked guide", isExpanded: $guideOpen) {
                        VStack(alignment: .leading, spacing: 12) {
                            assignment("Recognition cues", guide.recognition)
                            assignment("Core invariant", guide.invariant)
                            assignment("Anchor problem", guide.anchorProblem)
                            assignment("Answer guide", guide.answer)
                            assignment("Complexity", guide.complexity)
                        }
                        .padding(.top, 10)
                    }
                }

                GroupBox("Attempt record") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Status", selection: $status) {
                            ForEach(PracticeStatus.allCases) { Text($0.title).tag($0) }
                        }
                        Picker("Score", selection: $score) {
                            Text("Not scored").tag(Int?.none)
                            ForEach(1...4, id: \.self) { Text("\($0) / 4").tag(Int?.some($0)) }
                        }
                        PencilCapableTextEditor(
                            text: $notes,
                            minHeight: 130,
                            prompt: "Attempt notes, trade-offs, and what to improve…"
                        )
                        HStack {
                            Button("Record attempt") {
                                status = .attempted
                                save(increment: true)
                            }
                            Button("Mark completed") {
                                status = .completed
                                save(increment: false)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.staffGreen)
                            Spacer()
                            Button("Save notes") { save(increment: false) }
                        }
                    }
                }

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

    private func save(increment: Bool) {
        model.savePractice(
            itemID: item.id,
            status: status,
            score: score,
            notes: notes,
            incrementAttempt: increment
        )
    }
}
