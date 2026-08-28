import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("staff-deck-language-track") private var trackName = LanguageTrack.java.rawValue
    @State private var selection: SidebarDestination? = .workspace(.today)

    private var track: LanguageTrack { LanguageTrack(rawValue: trackName) ?? .java }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Picker("Language track", selection: $trackName) {
                    ForEach(LanguageTrack.allCases) { track in
                        Text(track.title).tag(track.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                Section("Workspace") {
                    ForEach(WorkspaceSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .tag(SidebarDestination.workspace(section))
                    }
                }

                ForEach(InterviewTopicGroup.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(InterviewTopic.topics(in: group, track: track)) { topic in
                            Label(topic.rawValue, systemImage: topic.systemImage)
                                .tag(SidebarDestination.topic(topic))
                        }
                    }
                }
            }
            .navigationTitle("Staff Deck")
            .safeAreaInset(edge: .bottom) {
                syncSummary
            }
        } detail: {
            Group {
                switch selection ?? .workspace(.today) {
                case let .topic(topic, targetCardID):
                    FlashcardsView(topic: topic, track: track, initialCardID: targetCardID)
                        .id(topic.id)
                case .workspace(.today, _):
                    TodayView(
                        track: track,
                        openTopic: { topic, cardID in selection = .topic(topic, targetCardID: cardID) },
                        openPractice: { itemID in selection = .workspace(.practice, targetItemID: itemID) },
                        openCareer: { _ in selection = .workspace(.career) }
                    )
                case .workspace(.progress, _):
                    LearningProgressView(track: track, openTopic: { selection = .topic($0) })
                case .workspace(.compare, _):
                    LanguageComparisonView()
                case let .workspace(.practice, targetItemID):
                    PracticeView(track: track, initialPracticeID: targetItemID)
                case .workspace(.career, _):
                    CareerView()
                case .workspace(.settings, _):
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.staffPaper)
        }
        .tint(.staffGreen)
        .onChange(of: trackName) { _, _ in
            selection = (selection ?? .workspace(.today)).resolved(for: track)
        }
    }

    private var syncSummary: some View {
        Button {
            if case .notConfigured = model.syncState {
                selection = .workspace(.settings)
            } else {
                Task { await model.syncNow() }
            }
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(syncColor)
                    .frame(width: 8, height: 8)
                Text(model.syncState.title)
                    .font(.caption)
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(8)
        }
        .buttonStyle(.plain)
    }

    private var syncColor: Color {
        switch model.syncState {
        case .connected: .green
        case .connecting: .orange
        case .notConfigured: .secondary
        case .offline: .red
        }
    }
}

extension Color {
    static let staffGreen = adaptive(
        light: (22, 63, 53),
        dark: (74, 176, 139)
    )
    static let staffLime = adaptive(
        light: (201, 242, 99),
        dark: (174, 211, 87)
    )
    static let staffCoral = adaptive(
        light: (240, 120, 95),
        dark: (255, 143, 121)
    )
    static let staffPaper = adaptive(
        light: (244, 242, 235),
        dark: (13, 21, 17)
    )
    static let staffSurface = adaptive(
        light: (255, 253, 248),
        dark: (23, 32, 27)
    )
    static let staffBorder = adaptive(
        light: (217, 221, 214),
        dark: (53, 69, 60)
    )

    private static func adaptive(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        #if os(macOS)
        let lightColor = NSColor(
            srgbRed: light.0 / 255,
            green: light.1 / 255,
            blue: light.2 / 255,
            alpha: 1
        )
        let darkColor = NSColor(
            srgbRed: dark.0 / 255,
            green: dark.1 / 255,
            blue: dark.2 / 255,
            alpha: 1
        )
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? darkColor
                : lightColor
        })
        #else
        return Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: value.0 / 255,
                green: value.1 / 255,
                blue: value.2 / 255,
                alpha: 1
            )
        })
        #endif
    }
}

struct SectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Color.staffGreen)
            Text(title)
                .font(.system(.largeTitle, design: .serif, weight: .medium))
            Text(subtitle)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "tray", description: Text(message))
    }
}
