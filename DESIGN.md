# StaffDeck Design System

This document codifies the visual and interaction language already implemented in the native SwiftUI app. It is an extraction contract, not a redesign brief: new work should compose the existing semantic colors, type styles, spacing rhythm, native controls, and rounded surfaces before introducing another pattern.

## 1. Foundations

StaffDeck is a calm, evidence-oriented study workspace. It should feel like a warm paper notebook organized with native Apple controls: editorial serif headings establish hierarchy, compact sans-serif controls support repeated work, and muted rounded surfaces separate content without turning the app into a card grid.

- **Signature:** warm paper and cream surfaces anchored by deep green, with lime and coral reserved for meaningful emphasis.
- **Platform posture:** native SwiftUI first. Preserve system behavior, Dynamic Type, keyboard navigation, pointer behavior, VoiceOver semantics, light/dark adaptation, and platform-standard control feedback.
- **Depth strategy:** mixed tonal shift and one-pixel border. `staffPaper` is the canvas; `staffSurface` is the raised working plane; `staffBorder` or a low-opacity semantic secondary stroke separates adjacent surfaces. Shadows are not part of the established language.
- **Density:** information-rich but not cramped. Long-form learning content stays left-aligned, with generous section gaps and compact metadata/control clusters.
- **Product persona:** a Staff-level interview candidate moving between keyboard-driven desktop study and touch, VoiceOver, or Apple Pencil use on iPad. The primary task is to capture credible evidence without accidentally submitting it.

## 2. Tokens

### Adaptive color palette

The named colors are defined once in `StaffDeck/RootView.swift` and adapt through `NSColor` on macOS and `UIColor` on iPadOS.

| Role | SwiftUI token | Light | Dark | Existing use |
|---|---|---:|---:|---|
| Brand / primary action | `Color.staffGreen` | `#163F35` | `#4AB08B` | Eyebrows, prominent-button tint, selection and primary emphasis |
| Bright positive accent | `Color.staffLime` | `#C9F263` | `#AED357` | Highlight and success-adjacent emphasis |
| Warm attention accent | `Color.staffCoral` | `#F0785F` | `#FF8F79` | Warnings, misses, and contrasting emphasis |
| App canvas | `Color.staffPaper` | `#F4F2EB` | `#0D1511` | Root/page background |
| Working surface | `Color.staffSurface` | `#FFFDF8` | `#17201B` | Cards, rails, editors, grouped content |
| Structural edge | `Color.staffBorder` | `#D9DDD6` | `#35453C` | Rounded-surface outlines and dividers |

Use SwiftUI semantic foreground styles for text and state that must track system accessibility settings:

- `.primary` for titles, requirements, and user-authored content.
- `.secondary` for descriptions, metadata, status context, and supporting copy.
- `.tertiary` for editor prompts only.
- System `.green`, `.orange`, and `.red` remain limited to connection/error state where already used.

Do not add a raw RGB/hex value in view code. Extend the `Color` namespace and this table first if a genuinely new semantic role is approved.

### Shape and edge tokens

| Intent | Existing value | Usage |
|---|---:|---|
| Editor radius | `8 pt` | `PencilCapableTextEditor` text surface |
| Compact callout radius | `12 pt` | Tinted callouts and compact grouped content |
| Standard surface radius | `14 pt` | Rails, cards, practice sections, and repeated working surfaces |
| Standard edge | `1 pt` | `staffBorder` or `secondary.opacity(0.2)` stroke |

Keep surfaces border/tonal-shift based. Do not introduce decorative shadows, glass, gradients, or a second corner-radius family for this workflow.

## 3. Typography

StaffDeck uses Apple system fonts and semantic SwiftUI text styles so content scales with platform settings. There is one deliberate family contrast: serif for editorial hierarchy, default system sans serif for controls and reading text.

| Role | SwiftUI style | Weight / design | Usage |
|---|---|---|---|
| Page title | `.system(.largeTitle, design: .serif, weight: .medium)` | Medium serif | `SectionHeader` page-level statement |
| Section title | `.system(.title, design: .serif, weight: .medium)` | Medium serif | Major workspace sections |
| Supporting title | `.title2` / `.title3` | Native default unless nearby code uses serif | Exercise and card hierarchy |
| Component title | `.headline` | Native semibold | Surface titles, requirements, rubric headings |
| Reading text | `.body` | Native regular | Prompts, artifacts, criteria, notes, coaching |
| Supporting text | `.callout` / `.subheadline` | Native regular | Hints, metadata, status, explanatory copy |
| Eyebrow / metadata | `.caption.weight(.bold)` or `.caption2.bold()` | Uppercase with `1–1.5 pt` tracking | Section labels and compact callouts |

Rules:

- Preserve the serif page/section hierarchy; do not apply serif to buttons, form labels, or dense metadata.
- Do not set fixed font sizes in view code. Use semantic styles for Dynamic Type and platform legibility.
- Long explanatory text uses `.fixedSize(horizontal: false, vertical: true)` where truncation would remove meaning.
- Uppercase is limited to short eyebrow labels, never requirements, errors, or user-authored evidence.

## 4. Layout & Spacing

The implicit system uses a `4 pt` base rhythm with optical half-steps already present in compact native-control clusters.

| Token / intent | Value | Existing use |
|---|---:|---|
| `space-tight` | `4 pt` | Icon/label and very compact metadata |
| `space-editor-inset` | `6 pt` | Text editor inset before its native text padding |
| `space-compact` | `8 pt` | Label-to-content, stacked metadata, criterion text |
| `space-control` | `10–12 pt` | Picker/filter clusters and button groups |
| `space-surface` | `14–16 pt` | Compact card padding and sibling surfaces |
| `space-section` | `20–22 pt` | Sections within a scrolling detail |
| `space-page` | `24–26 pt` | Page header/content insets |

- **Shell:** `NavigationSplitView` owns primary navigation. Content views own their scrolling; avoid nested scroll views unless the existing macOS split layout explicitly assigns internal detail scrolling.
- **Reading width:** long-form content is centered or left-anchored within an existing maximum width (for example the `980 pt` career workspace) rather than stretched edge to edge.
- **Adaptive composition:** `ViewThatFits(in: .horizontal)` changes horizontal filter/action clusters into vertical stacks when needed. `LazyVGrid(.adaptive(...))` is reserved for genuinely repeatable cards.
- **Practice workspace:** preserve the existing header, filters, exercise rail, detail order, and `.id(item.id)` identity reset. New criteria and evidence controls live inside the detail flow, before actions and coaching.
- **Touch targets:** interactive rows and buttons must expose at least a `44 pt` hit height on iPadOS. Extra hit area may be transparent; do not visually inflate compact macOS controls.

## 5. Primitives & Components

### Navigation split shell

- **Structure:** sidebar `List` and destination detail inside `NavigationSplitView`.
- **States:** selected, unselected, keyboard-focused, and connection-status feedback remain native.
- **Accessibility:** destination labels and native selection semantics; no gesture-only navigation.

### `SectionHeader`

- **Structure:** leading `VStack` of uppercase eyebrow, serif page title, and secondary subtitle.
- **Spacing:** `space-compact` internally; `space-page` around the containing page header.
- **States:** static content only.
- **Accessibility:** logical source order matches visual order; subtitle is allowed to wrap fully.

### Rounded working surface

- **Structure:** leading-aligned content on `staffSurface`, normally clipped or backed by a `RoundedRectangle(cornerRadius: 14)` and optionally outlined with `staffBorder`.
- **Variants:** standard `14 pt`, callout `12 pt`, editor `8 pt`.
- **States:** selected surfaces may use established green emphasis; error treatment uses semantic red text without inventing another surface color.
- **Accessibility:** color never carries selection, lock, or error state alone.

### Filter cluster and exercise rail

- **Structure:** labeled native `Picker`/`TextField` controls followed by a stable exercise list/rail and selected detail.
- **Layout:** horizontal when it fits; vertical fallback through `ViewThatFits`.
- **States:** filtered empty state uses `EmptyState`; selected exercise keeps visible icon/text status.
- **Accessibility:** native labels remain meaningful without surrounding visual context.

### `PencilCapableTextEditor`

- **Structure:** native `TextEditor` on a rounded `staffSurface`; iPadOS adds a segmented Type/Pencil mode and Pencil workspace.
- **States:** empty prompt, typed content, Pencil workspace, converted text.
- **Accessibility:** prompt is visual guidance, not an interactive overlay; the editor receives an explicit field label at the call site. Pencil is an alternative, never the only input path.

### Evidence criterion row

- **Structure:** a native `Toggle` whose label stacks the criterion requirement and its `evidencePrompt` hint.
- **Spacing:** `space-compact`; minimum `44 pt` interactive height on iPadOS.
- **States:** selected and not selected are exposed as the toggle value, not color alone.
- **Accessibility:** requirement is the label; selected/not-selected is the value; `evidencePrompt` is the hint. Rows follow source order from `PracticeItem.completionCriteria`.

### Practice status and submission actions

- **Status:** persisted `PracticeRecord.status` is read-only text with its existing icon/label treatment. A draft cannot choose or imply a submitted status.
- **Actions:** `Save draft` is bordered/secondary; `Submit attempt` is the single `borderedProminent` action tinted `staffGreen`.
- **States:** idle, dirty, validation failure, submitting/disabled, and submitted confirmation. Saving a draft never creates an attempt; submitting happens only from the explicit prominent action.
- **Accessibility:** validation appears inline and receives accessibility focus; successful submission posts one announcement.

### Coaching group

- **Locked:** render a native `GroupBox` labeled Guide or Model answer with “Submit evidence to unlock.” Do not construct hidden coaching children, so they cannot enter the accessibility tree.
- **Unlocked:** preserve the existing `DisclosureGroup` content. Guide and Model answer remain collapsed by default and never auto-open after submission.
- **Authority:** only `AppModel.hasSubmittedEvidence(for:)` unlocks coaching. Status, score, notes, generic rubric, draft fields, and attempt count are not proxies.

### Generic rubric and empty state

- `GeneralPracticeRubricView` remains supplemental guidance and cannot unlock coaching.
- `EmptyState` delegates to `ContentUnavailableView` with a title, SF Symbol, and descriptive text.

## 6. Interaction & Motion

- Use native control interaction, focus, disclosure, and scrolling behavior. The current system does not add custom animation timing or decorative motion.
- Every persistence action is explicit. Navigation, selection changes, view appearance, record refresh, and `Save draft` must never submit an attempt.
- Local editor state becomes dirty after score, notes, artifact, or criterion changes. Incoming persisted record changes refresh local state only while it is not dirty, preventing sync updates from overwriting active edits.
- Successful draft save clears dirty state after the model call. Explicit submit enters submitting state, calls the throwing submission API once, then moves to submitted or validation-failure state.
- Guide and Model answer disclosure state starts collapsed for each exercise identity and is not changed by unlock or submission.
- Respect Reduce Motion automatically by relying on native SwiftUI transitions; do not add new animation for validation, success, unlock, or status changes.

## 7. Responsive & Platform Behavior

### macOS

- Use the existing `GeometryReader`/fixed workspace sizing and internal detail-scroll branch where present so the rail and detail remain usable in a resizable window.
- Preserve compact pointer-sized native controls, keyboard navigation, focus rings, and bordered button hierarchy.
- Do not impose iPad minimum visual heights when a transparent content shape or native control already supplies an appropriate target.

### iPadOS

- The workspace participates in the native navigation stack/split behavior and may use an outer scroll view instead of the macOS internal-detail branch.
- Horizontal clusters collapse through `ViewThatFits`; content must remain readable in a single column without horizontal scrolling.
- Type/Pencil mode is available through `PencilCapableTextEditor`; typed evidence remains fully functional without Pencil hardware.
- Buttons, toggles, and criterion rows expose at least `44 pt` touch targets. Layout must tolerate Split View widths, Dynamic Type wrapping, and portrait/landscape changes.

### Shared

- Light/dark appearance comes from the six adaptive StaffDeck colors plus semantic system foreground styles.
- Keep the existing practice filtering, rail, navigation, order, and visual hierarchy unchanged. Platform conditionals may alter scroll ownership or input affordance, not model semantics.

## 8. Accessibility Constraints, Accepted Debt & Handoff

### Constraints

- Target WCAG 2.2 AA-equivalent native-app behavior: readable adaptive contrast, full keyboard reachability on macOS, VoiceOver-operable controls, Dynamic Type-safe wrapping on iPadOS, and no color-only state.
- Preserve logical order: assignment and persisted status; criteria; evidence artifact; score and notes; validation; draft/submit actions; supplemental rubric; locked or unlocked coaching.
- Criterion toggles expose requirement, selected/not-selected value, and evidence prompt hint. Locked coaching is a labeled group and contains no hidden answer descendants.
- Inline submission errors receive `@AccessibilityFocusState` focus. A successful explicit submission emits exactly one platform-appropriate accessibility announcement.
- Native visible focus and disabled states must remain intact. Do not replace buttons or toggles with tap gestures.
- Controls reflow rather than truncate essential text. Support larger text, VoiceOver, keyboard-only use, touch, pointer, and Pencil-with-typed-fallback users.

### Accepted debt

| Item | Location | Affected users / reason | Owner / exit |
|---|---|---|---|
| No automated rendered accessibility or contrast snapshot suite is present. | App-wide SwiftUI surfaces | Regressions currently depend on manual platform QA; this task does not add dependencies or test infrastructure. | App owner; add native UI/accessibility tests in a dedicated testing change. |
| Spacing is codified from repeated values but not centralized as Swift constants. | Existing views | Consolidating it now would alter unrelated files and exceed the preservation brief. | App owner; extract only with an approved app-wide refactor and visual baseline. |

No additional accessibility debt is accepted for the evidence-submission workflow. A failure in keyboard order, VoiceOver labeling/focus, 44 pt iPad targets, or coaching lock semantics blocks handoff.

### Handoff checklist

- Confirm changed views use only the color, type, spacing, shape, and control patterns documented above.
- Build the macOS target and inspect SourceKit diagnostics for changed Swift files.
- On macOS, verify keyboard traversal, draft-vs-submit behavior, sync-safe dirty edits, validation focus, one success announcement, and collapsed coaching after unlock.
- On iPadOS, verify Split View reflow, Dynamic Type wrapping, VoiceOver criterion value/hint, 44 pt targets, Type/Pencil evidence entry, and absence of locked coaching children.
- Record any deferred visual or accessibility issue in this section with affected users, severity, fix, owner, and explicit acceptance; do not hide it in a completion summary.
