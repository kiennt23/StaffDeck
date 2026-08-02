import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var databaseURL = ""
    @State private var authToken = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    eyebrow: "Cross-device data",
                    title: "Connect Staff Deck to Turso.",
                    subtitle: "The database URL and token stay in this device’s Keychain. Study content remains bundled; only your progress, notes, and career records sync."
                )

                GroupBox("Turso credentials") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("libsql://your-database-your-org.turso.io", text: $databaseURL)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            #endif
                        SecureField("Database auth token", text: $authToken)
                            .textFieldStyle(.roundedBorder)
                        Text("Create a dedicated database token. Staff Deck never stores it in source code or iCloud preferences.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                HStack {
                    Button("Connect and sync") {
                        Task {
                            await model.connect(
                                TursoCredentials(databaseURL: databaseURL, authToken: authToken)
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.staffGreen)
                    .disabled(databaseURL.isEmpty || authToken.isEmpty)

                    Button("Sync now") {
                        Task { await model.syncNow() }
                    }
                    .disabled(KeychainStore.load() == nil)

                    Spacer()

                    Button("Forget credentials", role: .destructive) {
                        Task {
                            await model.disconnectAndForget()
                            databaseURL = ""
                            authToken = ""
                        }
                    }
                    .disabled(KeychainStore.load() == nil)
                }

                syncStatus

                GroupBox("What syncs") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Flashcard review schedule and recall history", systemImage: "rectangle.stack")
                        Label("Practice status, score, attempts, notes, and next re-solve", systemImage: "hammer")
                        Label("Positioning, story bank, companies, contacts, and applications", systemImage: "briefcase")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }

                Text("Turso’s current Swift SDK is in technical preview. Staff Deck isolates it in one storage layer and always keeps a local cache, so the UI and your on-device work are not coupled to the driver.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 850, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Sync Settings")
        .onAppear {
            if let credentials = KeychainStore.load() {
                databaseURL = credentials.databaseURL
                authToken = credentials.authToken
            }
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        switch model.syncState {
        case .connected(let date):
            Label(
                "Last synced \(date.formatted(date: .omitted, time: .standard))",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .connecting:
            HStack {
                ProgressView()
                Text("Connecting to Turso…")
            }
        case .offline(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .notConfigured:
            Label("Enter your Turso credentials to enable cross-device sync.", systemImage: "icloud.slash")
                .foregroundStyle(.secondary)
        }
    }
}

