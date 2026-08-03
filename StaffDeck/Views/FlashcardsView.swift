import SwiftUI
#if os(iOS)
import PencilKit
import UIKit
import Vision
#endif

struct FlashcardsView: View {
    @EnvironmentObject private var model: AppModel
    let topic: InterviewTopic
    @State private var mode = "Review due"
    @State private var history = "Any history"
    @State private var query = ""
    @State private var index = 0
    @State private var revealed = false
    @State private var detail = "Answer"
    @State private var draftCardID: Int?
    @State private var answerDraft = ""
    @State private var analysisNotes = ""
    @State private var answerDrawing: Data?
    @State private var analysisDrawing: Data?
    @State private var answerInputMode = "Text"
    @State private var analysisInputMode = "Text"

    private var filtered: [Flashcard] {
        model.flashcards.filter { card in
            guard card.topic == topic.rawValue else { return false }
            guard query.isEmpty || [
                card.question, card.answer, card.example, card.topic,
            ].joined(separator: " ").localizedCaseInsensitiveContains(query) else { return false }
            if history == "New only", model.reviews[card.id] != nil { return false }
            if history == "Reviewed", model.reviews[card.id] == nil { return false }
            if mode == "Review due", let record = model.reviews[card.id] {
                return record.dueAt <= Date()
            }
            return true
        }
        .sorted { $0.id < $1.id }
    }

    private var current: Flashcard? {
        filtered.isEmpty ? nil : filtered[min(index, filtered.count - 1)]
    }

    private var dueCount: Int {
        model.flashcards.filter {
            guard $0.topic == topic.rawValue else { return false }
            return (model.reviews[$0.id]?.dueAt ?? .distantPast) <= Date()
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    SectionHeader(
                        eyebrow: topic.group.rawValue,
                        title: topic.rawValue,
                        subtitle: topic == .javaFundamentals
                            ? "Recall the rule first, then verify the mechanism, example, and interview note."
                            : "Answer first, then inspect the worked reasoning, Staff signal, and follow-ups."
                    )
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(dueCount)")
                            .font(.system(size: 38, weight: .semibold, design: .serif))
                        Text("cards due")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                controls

                if let current {
                    card(current)
                    navigation
                } else {
                    EmptyState(
                        title: mode == "Review due" ? "Review queue complete" : "No cards found",
                        message: mode == "Review due"
                            ? "Switch to Explore all or return when your next cards are due."
                            : "Try another topic or search."
                    )
                    .frame(minHeight: 360)
                }
            }
            .padding(28)
            .frame(maxWidth: 1_100)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(topic.rawValue)
        .onChange(of: query) { _, _ in resetPosition() }
        .onChange(of: mode) { _, _ in resetPosition() }
        .onChange(of: history) { _, _ in resetPosition() }
        .onChange(of: current?.id) { _, cardID in
            saveDraft()
            loadDraft(for: cardID)
        }
        .onAppear {
            loadDraft(for: current?.id)
        }
        .onDisappear {
            saveDraft()
        }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                modePicker
                searchField
                historyPicker
            }

            VStack(spacing: 10) {
                modePicker
                HStack(spacing: 10) {
                    searchField
                    historyPicker
                }
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            Text("Review due (\(dueCount))").tag("Review due")
            Text("Explore all").tag("Explore all")
        }
        .pickerStyle(.segmented)
        .frame(width: 300)
    }

    private var searchField: some View {
        TextField("Search cards", text: $query)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 180)
    }

    private var historyPicker: some View {
        Picker("History", selection: $history) {
            Text("Any history").tag("Any history")
            Text("New only").tag("New only")
            Text("Reviewed").tag("Reviewed")
        }
        .frame(width: 170)
    }

    private func card(_ card: Flashcard) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(card.topic)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.staffLime.opacity(0.35), in: Capsule())
                Spacer()
                Text("Card \(index + 1) of \(filtered.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(card.question)
                .font(.system(.title, design: .serif, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.vertical, revealed ? 4 : 40)

            answerEditor

            if revealed {
                HStack {
                    Spacer()
                    Button("Hide answer", systemImage: "eye.slash") {
                        withAnimation {
                            revealed = false
                        }
                    }
                    .buttonStyle(.borderless)
                }

                Picker("Answer section", selection: $detail) {
                    Text(topic == .javaFundamentals ? "Direct answer" : "Worked answer")
                        .tag("Answer")
                    Text(topic == .javaFundamentals ? "Key points" : "Answer map")
                        .tag("Outline")
                    Text("Follow-ups").tag("Follow-ups")
                }
                .pickerStyle(.segmented)

                Group {
                    switch detail {
                    case "Outline":
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(card.outline.enumerated()), id: \.offset) { number, item in
                                Label {
                                    Text(item)
                                } icon: {
                                    Text("\(number + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.staffGreen)
                                }
                            }
                        }
                    case "Follow-ups":
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(card.followUps, id: \.self) {
                                Label($0, systemImage: "questionmark.bubble")
                            }
                        }
                    default:
                        VStack(alignment: .leading, spacing: 16) {
                            Text(card.answer)
                                .font(.title3)
                                .lineSpacing(7)
                            callout("Concrete example", card.example, tint: .staffCoral)
                            callout(
                                topic == .javaFundamentals ? "Interview note" : "Staff signal",
                                card.staffSignal,
                                tint: .staffGreen
                            )
                        }
                    }
                }

                Divider()
                analysisEditor

                HStack {
                    ForEach(Rating.allCases) { rating in
                        Button(rating.title) {
                            model.rate(cardID: card.id, rating: rating)
                            move(1)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(tint(for: rating))
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Text(card.testing)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Button("Reveal answer") {
                    withAnimation { revealed = true }
                }
                .buttonStyle(.borderedProminent)
                .tint(.staffGreen)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .keyboardShortcut(.space, modifiers: [])
            }
        }
        .padding(26)
        .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.staffBorder)
        }
        .shadow(color: Color.black.opacity(0.07), radius: 24, y: 12)
    }

    private var answerEditor: some View {
        GroupBox("Your answer") {
            #if os(iOS)
            VStack(alignment: .leading, spacing: 10) {
                inputModePicker(selection: $answerInputMode)

                if answerInputMode == "Pencil" {
                    pencilEditor(
                        data: $answerDrawing,
                        text: $answerDraft,
                        label: "Handwritten answer"
                    ) {
                        answerInputMode = "Text"
                    }
                } else {
                    answerTextEditor
                }
            }
            #else
            answerTextEditor
            #endif
        }
    }

    private var answerTextEditor: some View {
        TextEditor(text: $answerDraft)
            .font(.title3)
            .frame(minHeight: 140)
            .padding(6)
            .background(Color.staffPaper, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.staffBorder)
            }
            .accessibilityLabel("Your answer")
    }

    private var analysisTextEditor: some View {
        TextEditor(text: $analysisNotes)
            .frame(minHeight: 110)
            .padding(6)
            .background(Color.staffPaper, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.staffBorder)
            }
            .accessibilityLabel("Answer analysis notes")
    }

    #if os(iOS)
    private func inputModePicker(selection: Binding<String>) -> some View {
        Picker("Input method", selection: selection) {
            Text("Type").tag("Text")
            Label("Pencil", systemImage: "pencil.tip").tag("Pencil")
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 280)
    }

    private func pencilEditor(
        data: Binding<Data?>,
        text: Binding<String>,
        label: String,
        converted: @escaping () -> Void
    ) -> some View {
        PencilWorkspaceLauncher(
            drawingData: data,
            text: text,
            label: label,
            converted: converted
        )
    }
    #endif

    private var analysisEditor: some View {
        GroupBox("Answer analysis notes") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Capture what you missed, what you would structure differently, and the evidence you want to remember.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                #if os(iOS)
                inputModePicker(selection: $analysisInputMode)

                if analysisInputMode == "Pencil" {
                    pencilEditor(
                        data: $analysisDrawing,
                        text: $analysisNotes,
                        label: "Handwritten answer analysis notes"
                    ) {
                        analysisInputMode = "Text"
                    }
                } else {
                    analysisTextEditor
                }
                #else
                analysisTextEditor
                #endif

                HStack {
                    Spacer()
                    Button("Save answer & notes") {
                        saveDraft()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var navigation: some View {
        HStack {
            Button("Previous", systemImage: "arrow.left") { move(-1) }
            Spacer()
            Text("Say the invariant, trade-offs, and operational proof aloud.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Next", systemImage: "arrow.right") { move(1) }
                .labelStyle(.titleAndIcon)
        }
    }

    private func callout(_ title: String, _ body: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .tracking(1)
                .foregroundStyle(tint)
            Text(body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func tint(for rating: Rating) -> Color {
        switch rating {
        case .again: .red
        case .hard: .orange
        case .good: .staffGreen
        case .easy: .blue
        }
    }

    private func resetPosition() {
        index = 0
        revealed = false
        detail = "Answer"
    }

    private func move(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        index = (index + delta + filtered.count) % filtered.count
        revealed = false
        detail = "Answer"
    }

    private func loadDraft(for cardID: Int?) {
        draftCardID = cardID
        guard let cardID else {
            answerDraft = ""
            analysisNotes = ""
            return
        }
        answerDraft = model.flashcardWork[cardID]?.answer ?? ""
        analysisNotes = model.flashcardWork[cardID]?.analysisNotes ?? ""
        answerDrawing = model.flashcardWork[cardID]?.answerDrawing
        analysisDrawing = model.flashcardWork[cardID]?.analysisDrawing
    }

    private func saveDraft() {
        guard let draftCardID else { return }
        model.saveFlashcardWork(
            cardID: draftCardID,
            answer: answerDraft,
            analysisNotes: analysisNotes,
            answerDrawing: answerDrawing,
            analysisDrawing: analysisDrawing
        )
    }
}

#if os(iOS)
struct PencilDrawingCanvas: UIViewRepresentable {
    @Binding var drawingData: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.tool = PKInkingTool(.pen, color: .black, width: 5)
        canvas.isScrollEnabled = false
        canvas.isUserInteractionEnabled = true
        canvas.isMultipleTouchEnabled = true
        canvas.drawingPolicy = .anyInput
        canvas.isDrawingEnabled = true
        canvas.drawingGestureRecognizer.isEnabled = true

        if let drawingData, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        context.coordinator.lastSyncedDrawingData = drawingData

        let toolPicker = context.coordinator.toolPicker
        toolPicker.stateAutosaveName = "StaffDeck.PencilTools"
        toolPicker.showsDrawingPolicyControls = false
        toolPicker.addObserver(canvas)
        if !canvas.isDrawingEnabled,
           let inkingItem = toolPicker.toolItems.first(where: { $0 is PKToolPickerInkingItem })
        {
            toolPicker.selectedToolItem = inkingItem
        }
        canvas.drawingPolicy = .anyInput
        canvas.isDrawingEnabled = true

        DispatchQueue.main.async {
            canvas.becomeFirstResponder()
            toolPicker.setVisible(true, forFirstResponder: canvas)
        }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.drawingPolicy = .anyInput
        canvas.isDrawingEnabled = true
        canvas.drawingGestureRecognizer.isEnabled = true

        guard
            let drawingData,
            drawingData != context.coordinator.lastSyncedDrawingData,
            let drawing = try? PKDrawing(data: drawingData)
        else {
            if
                drawingData == nil,
                context.coordinator.lastSyncedDrawingData != nil,
                !canvas.drawing.strokes.isEmpty
            {
                context.coordinator.isApplyingDrawing = true
                canvas.drawing = PKDrawing()
                context.coordinator.isApplyingDrawing = false
                context.coordinator.lastSyncedDrawingData = nil
            }
            return
        }

        context.coordinator.isApplyingDrawing = true
        canvas.drawing = drawing
        context.coordinator.isApplyingDrawing = false
        context.coordinator.lastSyncedDrawingData = drawingData
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.pendingSave?.cancel()
        coordinator.persistDrawing(from: canvas)
        coordinator.toolPicker.setVisible(false, forFirstResponder: canvas)
        canvas.resignFirstResponder()
        coordinator.toolPicker.removeObserver(canvas)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilDrawingCanvas
        let toolPicker = PKToolPicker()
        var lastSyncedDrawingData: Data?
        var isApplyingDrawing = false
        var pendingSave: DispatchWorkItem?

        init(parent: PencilDrawingCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // PencilKit calls this repeatedly during a stroke. Serializing and
            // publishing here blocks its low-latency renderer.
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            pendingSave?.cancel()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            pendingSave?.cancel()
            let work = DispatchWorkItem { [weak self, weak canvasView] in
                guard let self, let canvasView else { return }
                self.persistDrawing(from: canvasView)
            }
            pendingSave = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
        }

        func persistDrawing(from canvasView: PKCanvasView) {
            guard !isApplyingDrawing else { return }
            let strokeCount = canvasView.drawing.strokes.count
            let nextData = strokeCount == 0
                ? nil
                : canvasView.drawing.dataRepresentation()
            lastSyncedDrawingData = nextData
            parent.drawingData = nextData
        }
    }
}

struct PencilWorkspaceLauncher: View {
    @Binding var drawingData: Data?
    @Binding var text: String
    let label: String
    let converted: () -> Void
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isPresented = true
            } label: {
                Label(
                    drawingData == nil ? "Open writing canvas" : "Continue handwriting",
                    systemImage: "pencil.and.scribble"
                )
                .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(.bordered)

            Text("The canvas opens full screen. Draw with Apple Pencil or one finger.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            DispatchQueue.main.async {
                isPresented = true
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            PencilWorkspace(
                drawingData: $drawingData,
                text: $text,
                title: label
            ) {
                converted()
                isPresented = false
            }
        }
    }
}

private struct PencilWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var drawingData: Data?
    @Binding var text: String
    let title: String
    let converted: () -> Void

    var body: some View {
        NavigationStack {
            PencilDrawingCanvas(drawingData: $drawingData)
            .background(Color.white)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Type", systemImage: "keyboard") {
                        converted()
                    }
                    PencilTextConversionButton(
                        drawingData: $drawingData,
                        text: $text
                    ) {
                        converted()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Text("Draw with Apple Pencil or one finger")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .background(.regularMaterial)
            }
        }
    }
}

struct PencilTextConversionButton: View {
    @Binding var drawingData: Data?
    @Binding var text: String
    let converted: () -> Void
    @State private var isConverting = false
    @State private var conversionMessage: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                convert()
            } label: {
                if isConverting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Convert to text", systemImage: "text.viewfinder")
                }
            }
            .buttonStyle(.bordered)
            .disabled(drawingData == nil || isConverting)

            if let conversionMessage {
                Text(conversionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func convert() {
        guard let drawingData else { return }
        isConverting = true
        conversionMessage = nil
        Task {
            do {
                let recognized = try await HandwritingRecognizer.recognize(drawingData)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = recognized
                } else {
                    text += "\n" + recognized
                }
                conversionMessage = "Added to typed text"
                converted()
            } catch {
                conversionMessage = error.localizedDescription
            }
            isConverting = false
        }
    }
}

@MainActor
private enum HandwritingRecognizer {
    static func recognize(_ data: Data) async throws -> String {
        let drawing = try PKDrawing(data: data)
        guard !drawing.strokes.isEmpty else {
            throw HandwritingRecognitionError.emptyDrawing
        }

        if #available(iOS 27.0, *) {
            let recognizer = PKStrokeRecognizer()
            await recognizer.updateDrawing(drawing)
            if let recognized = await recognizer.recognizedText() {
                let result = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
                if !result.isEmpty {
                    return result
                }
            }
        }

        return try await recognizeRenderedDrawing(drawing)
    }

    private static func recognizeRenderedDrawing(_ drawing: PKDrawing) async throws -> String {
        let sourceRect = drawing.bounds.insetBy(dx: -24, dy: -24)
        let renderedDrawing = drawing.image(from: sourceRect, scale: 2)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2
        let image = UIGraphicsImageRenderer(
            size: sourceRect.size,
            format: format
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: sourceRect.size))
            renderedDrawing.draw(in: CGRect(origin: .zero, size: sourceRect.size))
        }
        guard let image = image.cgImage else {
            throw HandwritingRecognitionError.renderFailed
        }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let observations = try await request.perform(on: image)
        let result = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.isEmpty else {
            throw HandwritingRecognitionError.noTextFound
        }
        return result
    }
}

private enum HandwritingRecognitionError: LocalizedError {
    case emptyDrawing
    case renderFailed
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .emptyDrawing:
            "Write something before converting."
        case .renderFailed:
            "The handwriting could not be prepared for recognition."
        case .noTextFound:
            "No handwriting was recognized. Try writing a little larger."
        }
    }
}
#endif

struct PencilCapableTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat
    var prompt = ""
    #if os(iOS)
    @State private var inputMode = "Text"
    @State private var drawingData: Data?
    #endif

    var body: some View {
        #if os(iOS)
        VStack(alignment: .leading, spacing: 8) {
            Picker("Input method", selection: $inputMode) {
                Text("Type").tag("Text")
                Label("Pencil", systemImage: "pencil.tip").tag("Pencil")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)

            if inputMode == "Pencil" {
                PencilWorkspaceLauncher(
                    drawingData: $drawingData,
                    text: $text,
                    label: "Handwritten notes"
                ) {
                    inputMode = "Text"
                }
            } else {
                textEditor
            }
        }
        #else
        textEditor
        #endif
    }

    private var textEditor: some View {
        TextEditor(text: $text)
            .font(.body)
            .frame(minHeight: minHeight)
            .padding(6)
            .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            }
            .overlay(alignment: .topLeading) {
                if text.isEmpty && !prompt.isEmpty {
                    Text(prompt)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
    }
}
