import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: SidebarDestination? = .topic(.javaFundamentals)

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(InterviewTopicGroup.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(InterviewTopic.topics(in: group)) { topic in
                            Label(topic.rawValue, systemImage: topic.systemImage)
                                .tag(SidebarDestination.topic(topic))
                        }
                    }
                }

                Section("Workspace") {
                    ForEach(WorkspaceSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .tag(SidebarDestination.workspace(section))
                    }
                }
            }
            .navigationTitle("Staff Deck")
            .safeAreaInset(edge: .bottom) {
                syncSummary
            }
        } detail: {
            Group {
                switch selection ?? .topic(.javaFundamentals) {
                case let .topic(topic):
                    FlashcardsView(topic: topic)
                        .id(topic.id)
                case .workspace(.practice):
                    PracticeView()
                case .workspace(.career):
                    CareerView()
                case .workspace(.settings):
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.staffPaper)
        }
        .tint(.staffGreen)
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
