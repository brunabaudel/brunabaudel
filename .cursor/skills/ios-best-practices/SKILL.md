---
name: ios-best-practices
description: iOS/Swift best practices for building the Ebb app (SwiftUI, @Observable MVVM, SwiftData + CloudKit, HealthKit, Speech, Foundation Models, StoreKit 2). Use when writing, reviewing, or refactoring any Swift code in this repo — views, view models, services, data models, tests, or the Xcode project itself.
---

# iOS Best Practices (Ebb)

Ebb is a privacy-first, on-device symptom tracker. Read `docs/ebb-build-plan.md` (architecture section) and `docs/symptom-tracker-classification-spec.md` before making structural changes. Two rules override everything else:

1. **Health data never leaves the device.** No analytics SDKs, no remote logging, no server calls with entry data. The only "cloud" is the user's own CloudKit private database.
2. **The schema JSON is the single source of truth.** UI controls and model vocabulary both render from `symptom-schema.json`. Never hardcode a symptom, trigger, or enum value in Swift.

## Architecture

- Lightweight MVVM: `@Observable` view models **only** for screens with orchestration (Talk/Confirm, Patterns, Onboarding). Simple screens use SwiftData `@Query` directly in the view. Do not create pass-through view models.
- Every risky capability lives behind a protocol in `Services/` with a real + mock implementation: `SymptomClassifier`, `SpeechCapture`, `CycleService`, `Entitlements`. Views never import HealthKit/Speech/StoreKit directly.
- Organize by feature (`Features/Today/`, `Features/Log/`...), shared code in `Models/`, `DesignSystem/`, `Services/`.
- No repository abstraction over SwiftData; it is the source of truth and CloudKit sync stays behind it.
- No third-party dependencies without strong justification. Prefer Apple frameworks.

## SwiftUI

- iOS 17+ observation only: `@Observable` + `@State`/`@Environment`/`@Bindable`. Never introduce `ObservableObject`, `@StateObject`, `@Published`, or Combine for new code.
- Views are dumb. Logic that needs a unit test does not belong in a view body.
- All colors come from the theme-tokens layer via `Environment` — never `Color(hex:)` or asset colors directly in a screen. Warm accent = pain, cool accent = cycle, in every theme.
- Every new component gets a `#Preview` with mock data (previews must not touch HealthKit, Speech, or the network).
- Accessibility is not optional for this audience (users are mid-migraine): support Dynamic Type (no fixed font sizes), VoiceOver labels on custom controls (pills, phase ring), Reduce Motion variants for animations (the breathing orb).
- Prefer `NavigationStack` with typed destinations; keep navigation state in one place per feature.

## Concurrency

- Swift concurrency only: `async/await`, `actor`, `@MainActor`. No GCD (`DispatchQueue`), no completion handlers in new code.
- View models are `@MainActor`. Services doing I/O (HealthKit, speech, inference) are actors or expose `async` methods.
- Streams (live transcription, model tokens) are `AsyncSequence`/`AsyncStream`, consumed with `for await` in a `.task` modifier so cancellation is automatic.
- Treat compiler strict-concurrency warnings as errors; fix them, don't `@unchecked Sendable` them away.

## SwiftData + CloudKit

- Keep models CloudKit-compatible from day one: all properties optional or with defaults, no `@Attribute(.unique)`, relationships optional.
- Stamp `schemaVersion` on every saved entry. Additive schema changes only; never rename/retype a stored property without a migration plan.
- Validate every field key/value against `SchemaConfig` before saving — including values returned by the classifier (validation gate, belt-and-suspenders with constrained decoding).
- Store the verbatim transcript in `note` untouched. Never rewrite the user's words.

## On-device AI (SymptomClassifier)

- All inference behind the `SymptomClassifier` protocol; Apple Foundation Models and MLX/Qwen are swappable implementations. Never call a model API from a view or view model directly.
- Build `[ALLOWED_FIELDS]` for the prompt from `symptom-schema.json` at runtime — never paste enum values into the prompt by hand.
- Use guided generation / constrained decoding (`@Generable`) so off-menu output is structurally impossible; then still run the validation gate.
- The model only pre-fills; the user always confirms. No AI-classified entry is ever saved without passing through the Confirm screen.
- When mapping fails, prefer omission over guessing (an empty result is a valid, correct answer). Grow synonym lists in the schema JSON from real misses — that is the fix, not prompt hacks.
- Any test of classifier behavior must cover the four failure modes: multi-field decomposition, negation, synonyms/foreign words, ambiguity → `{}`.

## Privacy & permissions

- Request permissions in context (mic when first tapping Talk, HealthKit when first opening cycle features), never all at once at launch. Every permission has a graceful denial path (Talk denied → Tap still works).
- All `NS*UsageDescription` strings must explain the on-device promise.
- Speech recognition must set on-device-only options; assert it in code, not just settings.
- App lock via `LocalAuthentication`; no identity, no accounts, no email — ever.
- Keep the "self-tracking, not diagnostic" framing in all user-facing copy. Never generate advice, diagnosis, or medical interpretation.

## StoreKit / paywall

- StoreKit 2 (`Product`, `Transaction.currentEntitlements`) behind the `Entitlements` service — one gate point for every Ebb+ check.
- Never gate logging, safety (iCloud backup, app lock), or the default theme. Never show the paywall during attack logging.

## Testing & tooling

- Swift Testing (`@Test`, `#expect`) for new tests. Unit-test the pure layers hard: `StatsEngine`, schema loading/validation, cycle-phase derivation, classifier output validation.
- UI flows tested with mock services injected; no test may hit HealthKit, the network, or real inference.
- Keep the GitHub Actions TestFlight workflow (`.github/workflows/testflight.yml`) green; the project must always build with `xcodebuild` from a clean checkout.
- When adding files to the Xcode project, edit `project.pbxproj` carefully or use a folder-reference structure; verify the target builds afterwards.

## Code style

- Value types by default; `final class` only where reference semantics are required (`@Observable` view models, actors).
- No force-unwraps outside tests; `guard let` with a meaningful early exit.
- Errors: typed `Error` enums per service; user-facing failures degrade gracefully (classifier failure → empty Confirm screen, never a blocking alert mid-migraine).
- Comments explain *why* (a constraint, a trade-off, a spec reference), never *what* the code does.
