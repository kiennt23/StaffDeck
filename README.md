# Staff Deck for macOS and iPadOS

Native SwiftUI version of Staff Deck. One Xcode target runs on both macOS and
iPadOS. The 300 flashcards and 240 practice exercises are bundled with the app;
personal progress and career records sync through Turso.

## Included

- spaced-review flashcards with answer maps and follow-ups
- general and DSA practice lab with scores, notes, attempts, and re-solve dates
- résumé positioning and a Staff story bank
- company research, networking, and application/interview tracking
- local cache for offline use
- Turso reconciliation across devices using last-write-wins timestamps
- tombstones for career-record deletion
- Turso credentials stored in Apple Keychain

## Create the Xcode project

XcodeGen is used so the project definition stays reviewable.

```bash
xcodegen generate
open StaffDeck.xcodeproj
```

To refresh the bundled study content, the exporter reads generated content from
the Staff Deck web project and checks the expected counts before writing the app
resources. It merges the maintained Java fundamentals, Go track, subtopic, and
concise-answer overrides under `Content/` before exporting. Point it at the web
project explicitly:

```bash
STAFF_DECK_WEB_ROOT=/path/to/flashcards-app node Scripts/export-content.mjs
```

## Create the Turso database

Install and sign in to the Turso CLI, then create a database and a dedicated
database token:

```bash
turso auth login
turso db create staff-deck
turso db show --url staff-deck
turso db tokens create staff-deck
```

Open **Sync Settings** in Staff Deck on each device and paste the same database
URL and token. The app creates the idempotent schema from
`Database/schema.sql` on first connection.

Do not commit or paste the token into a build setting. It is intentionally
entered at runtime and stored in Keychain.

## Run on macOS

In Xcode, choose **My Mac** and Run. For a local unsigned build:

```bash
xcodebuild \
  -project StaffDeck.xcodeproj \
  -scheme StaffDeck \
  -destination 'platform=macOS' \
  -derivedDataPath .build/macos \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Run on iPad

In Xcode:

1. Select the Staff Deck target and choose your Apple Development team.
2. Connect the iPad, trust the Mac if prompted, and select the iPad destination.
3. Run the app. For a personal team, iPadOS may ask you to trust the developer
   profile in **Settings > General > VPN & Device Management**.
4. Enter the same Turso URL and token in **Sync Settings**.

The iPad simulator build can be checked without signing:

```bash
xcodebuild \
  -project StaffDeck.xcodeproj \
  -scheme StaffDeck \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=18.5' \
  -derivedDataPath .build/ipados \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Tests

```bash
xcodebuild \
  -project StaffDeck.xcodeproj \
  -scheme StaffDeck \
  -destination 'platform=macOS' \
  -derivedDataPath .build/signed-tests \
  test
```

The Turso Swift SDK is currently in technical preview. All driver usage lives
in `StaffDeck/TursoStore.swift`, while app state is cached locally and the
database schema is a generic versioned-record surface. This keeps a future
driver or API change isolated.
