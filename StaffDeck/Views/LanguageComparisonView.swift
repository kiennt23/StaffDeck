import SwiftUI

struct LanguageComparisonView: View {
    @State private var selectedID = LanguageComparisonContent.items[0].id
    @State private var revealed = false

    private var selected: LanguageComparison {
        LanguageComparisonContent.items.first { $0.id == selectedID }
            ?? LanguageComparisonContent.items[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(
                    eyebrow: "Transfer the concept, not the syntax",
                    title: "Compare Java and Go",
                    subtitle: "Learn one production concern through both language ecosystems, then explain the invariant and the decision rule without relying on either implementation." 
                )

                Picker("Concept", selection: $selectedID) {
                    ForEach(LanguageComparisonContent.items) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedID) { _, _ in revealed = false }

                HStack(alignment: .top, spacing: 14) {
                    implementationCard(
                        language: "Java",
                        icon: "cup.and.saucer",
                        points: selected.java,
                        tint: .staffGreen
                    )
                    implementationCard(
                        language: "Go",
                        icon: "g.circle",
                        points: selected.go,
                        tint: .staffCoral
                    )
                }

                GroupBox("Invariant across languages") {
                    Text(selected.invariant)
                        .lineSpacing(4)
                        .padding(.top, 8)
                }

                GroupBox("Staff-level decision rule") {
                    Text(selected.staffDecision)
                        .lineSpacing(4)
                        .padding(.top, 8)
                }

                GroupBox("Retrieval drill") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selected.prompt)
                            .font(.headline)
                        if revealed {
                            Text(selected.answer)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                            Button("Hide answer") { revealed = false }
                        } else {
                            Button("Reveal answer") { revealed = true }
                                .buttonStyle(.borderedProminent)
                                .tint(.staffGreen)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(28)
            .frame(maxWidth: 1_000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Compare Languages")
    }

    private func implementationCard(
        language: String,
        icon: String,
        points: [String],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(language, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            ForEach(points, id: \.self) {
                Label($0, systemImage: "checkmark.circle")
                    .font(.callout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.staffSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.staffBorder) }
    }
}

private struct LanguageComparison: Identifiable {
    let id: String
    let title: String
    let java: [String]
    let go: [String]
    let invariant: String
    let staffDecision: String
    let prompt: String
    let answer: String
}

private enum LanguageComparisonContent {
    static let items: [LanguageComparison] = [
        item("Transfer exercise: dependency client", ["Express timeout budgets, idempotency, retry policy, pool limits, and stable error mapping in a Java client."], ["Express the same contract with context deadlines, idempotency, retry policy, pool limits, and stable error mapping."], "The client contract and capacity budget are language-independent.", "Review the invariant first; accept Java exceptions and Go errors as different implementation mechanisms.", "Translate a dependency client from Java to Go. What must not change?", "Timeout budget, idempotency, retry eligibility, error semantics, telemetry, and pool admission must remain equivalent; context and error wrapping replace Java-specific mechanics."),
        item("Transfer exercise: database boundary", ["Use explicit transaction boundaries; prevent ORM lifecycle and retry behavior from obscuring consistency."], ["Use explicit transaction boundaries; propagate context and close rows while making scan and null semantics explicit."], "Schema compatibility, transaction scope, idempotency, and migration safety are product contracts.", "Require both implementations to pass the same migration, rollback, and outbox failure scenarios.", "What changes when translating a transactional outbox from Java to Go?", "The driver and transaction APIs change, but atomic write intent, relay idempotency, ordering assumptions, and backlog observability do not."),
        item("Transfer exercise: secure service boundary", ["Verify identity at a framework boundary, authorize explicit actions and tenant scope, then emit safe audit events."], ["Verify identity in middleware, place only trusted identity in context, authorize explicit actions and tenant scope, then emit safe audit events."], "Trust boundaries, tenant isolation, denial behavior, and audit evidence cannot vary by language.", "Test the same abuse cases in both services rather than standardizing their framework APIs.", "Which security behavior must be identical across Java and Go?", "Authentication trust roots, authorization policy, tenant checks, data exposure rules, audit records, and rollout verification must match exactly."),
        item("Runtime lifecycle and saturation", ["Executors and virtual threads still need admission limits, interruption, and explicit shutdown.", "Use JFR, thread dumps, queue metrics, and dependency waits to classify latency."], ["Goroutines still need admission limits, context cancellation, and explicit shutdown.", "Use pprof, traces, goroutine counts, and dependency waits to classify latency."], "Cheap execution does not create downstream capacity; every unit of work needs an owner, budget, cancellation path, and observable queue.", "Use one incident model across languages—impact, saturation signal, blocking evidence, safe containment, and validation—not one runtime's vocabulary.", "CPU is low but p99 and queues are rising. What do you inspect before scaling?", "Inspect traces, queue and pool waits, blocked execution evidence, lock contention, and downstream latency. Scaling can amplify an already saturated dependency."),
        item("Testing and dependencies", ["Use Maven/Gradle lockfiles, dependency checks, JUnit 5, Testcontainers, and contract tests.", "Keep unit tests deterministic; isolate real dependencies behind disposable integration environments."], ["Use Go modules with pinned versions, go.sum review, table tests, fuzzing, race detection, and disposable integration dependencies.", "Keep tests deterministic and run -race for concurrent code."], "A build must be reproducible, dependency changes must be reviewable, and tests must prove behavior at the right boundary.", "Standardize quality gates and reusable test infrastructure; do not force every service into the same test pyramid or framework.", "How would you add a database integration test without making local development or CI flaky?", "Use an isolated disposable database, apply migrations deterministically, bound startup and test deadlines, and retain logs or artifacts only when a failure needs diagnosis."),
        item("Error handling", ["Exceptions encode non-local error flow.", "Translate exception types at the transport boundary.", "Do not use catch-all handling to hide dependency failure."], ["Errors are returned explicitly and wrapped with context.", "Use errors.Is and errors.As for classification.", "Reserve panic for broken invariants."], "Expected failure must remain visible, classified, observable, and safe to retry or expose.", "Choose the mechanism idiomatic to the service language, then standardize the error taxonomy and boundary mapping across services.", "How would you classify a downstream timeout without leaking provider details to an API caller?", "Map a trusted domain error at the boundary, preserve the cause for telemetry, and retain retryability or idempotency semantics internally."),
        item("Cancellation and deadlines", ["Thread interruption, CompletableFuture cancellation, and request deadlines need deliberate propagation.", "Blocking clients must honor timeouts and cancellation."], ["context.Context carries cancellation and deadline through calls.", "Goroutines must select on ctx.Done and release resources."], "Work that outlives its caller must have an explicit owner, budget, and cleanup path.", "Set the deadline at ingress, propagate it to every blocking dependency, and measure cancellation instead of treating timeout as a cosmetic client setting.", "Why is a timeout on only the outer HTTP handler insufficient?", "Queued work, database calls, RPCs, and spawned work can continue consuming capacity unless the budget propagates to each boundary."),
        item("Concurrency and capacity", ["Executors, virtual threads, locks, and connection pools each bound different resources.", "Cheap threads do not increase database capacity."], ["Goroutines, channels, mutexes, and pools require explicit lifecycle and backpressure.", "Cheap goroutines do not increase database capacity."], "Execution concurrency and downstream capacity are separate limits; both need observability and backpressure.", "Pick the simplest synchronization mechanism, then size admission and dependency limits from measured capacity rather than language runtime defaults.", "Would virtual threads or goroutines solve a saturated database pool?", "No. They can improve blocking-work efficiency, but the pool and database remain the bottleneck; unbounded work can worsen queueing and tail latency."),
        item("Data ownership", ["Immutable values and defensive copies protect callers from shared mutable state.", "Collections need documented ownership and thread-safety contracts."], ["Slices can share backing arrays; maps are mutable and unsafe for concurrent writes.", "Copy values at async, cache, and API ownership boundaries."], "A caller must know whether it owns, may mutate, or must treat returned data as immutable.", "Make ownership explicit in the API contract; copy only at real isolation boundaries, then test aliasing and concurrent access failures.", "When is returning a collection or slice directly unsafe?", "When a caller can mutate data retained by the producer, or when a shared backing store crosses a concurrent, cached, or asynchronous boundary."),
        item("Runtime diagnosis", ["Use JFR, async-profiler, heap/thread dumps, GC, and executor metrics.", "Separate CPU, allocation, locks, and downstream waits."], ["Use pprof CPU, heap, goroutine, block, and mutex profiles with runtime metrics.", "Separate CPU, allocation, blocked goroutines, locks, and downstream waits."], "A profile is evidence for a hypothesis, not proof of a root cause; compare it under a controlled workload with request-level telemetry.", "Build a cross-language diagnostic playbook around symptoms and evidence types, not tool names. Require a rollback and validation signal before changing production.", "A process has high p99 latency but low average CPU. What evidence do you gather first?", "Check request traces, queue and connection-pool waits, blocked-thread or goroutine profiles, lock contention, and dependency latency before assuming compute saturation."),
        item("Service boundaries", ["Framework annotations and dependency injection can obscure transaction and lifecycle boundaries.", "Keep domain contracts independent from Spring transport details."], ["net/http or gRPC handlers should remain thin and pass context into domain code.", "Avoid storing request context or transport state in long-lived services."], "Transport, domain logic, persistence, and operational policy should have explicit boundaries regardless of framework style.", "Standardize the contract—timeouts, errors, auth, idempotency, observability—rather than imposing one language's framework pattern on every service.", "What should be identical between a Java and Go implementation of the same API?", "Its externally observable contract: authorization, validation, idempotency, error semantics, SLOs, audit events, and compatibility behavior—not its internal concurrency or framework idioms.")
    ]

    private static func item(_ title: String, _ java: [String], _ go: [String], _ invariant: String, _ decision: String, _ prompt: String, _ answer: String) -> LanguageComparison {
        LanguageComparison(id: title, title: title, java: java, go: go, invariant: invariant, staffDecision: decision, prompt: prompt, answer: answer)
    }
}
