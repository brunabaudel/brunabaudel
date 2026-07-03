# Ebb — Build Plan

*Step-by-step plan to take the existing `Ebb` Xcode skeleton to the v1 described in the product spec. Ordered UI-first, then the local AI, then privacy/monetization/release. Each phase ships something runnable on TestFlight.*

Companion docs: `symptom-tracker-product-spec.md` (master), `symptom-tracker-classification-spec.md` (schema — the build anchor), `symptom-tracker-ui-design.html`, `symptom-tracker-palettes.html`, `symptom-tracker-theme-picker.html`, `symptom-tracker-paywall.html`, `symptom-tracker-business-plan.md`.

---

## Architecture ✦ decided

**Lightweight MVVM on `@Observable`, with a protocol-based services layer, organized by feature.** No third-party architecture framework (no TCA, no VIPER) — the app leans on SwiftUI, SwiftData, HealthKit, Foundation Models, and StoreKit, all of which want to live close to Apple's native lifecycle; a solo indie ships faster without fighting an abstraction on top of them.

Three layers:

**1. Services layer (protocol-first) — where the architecture earns its keep.** Each risky capability sits behind a small protocol with a real and a mock implementation:

| Service | Role | Why a protocol |
|---|---|---|
| `SymptomClassifier` | transcript → schema-valid field values | the load-bearing seam: Apple Foundation Models and MLX/Qwen are two implementations — the EU-availability decision changes one file, not the app |
| `SpeechCapture` | on-device speech-to-text stream | mockable for UI tests; API differs across iOS versions |
| `CycleService` | HealthKit reads + cycle-phase derivation | HealthKit unavailable in previews/simulator |
| `Entitlements` | StoreKit 2 subscription state | single gate point for every Ebb+ check |
| `StatsEngine` | pattern/correlation math | pure functions, deterministic, unit-tested — no protocol needed |

The **schema config** (`SchemaConfig` loaded from the bundled JSON) is a value type passed down, not a service — it's data.

**2. ViewModels only where there's orchestration.** `@Observable` classes for screens with real logic: Talk/Confirm (speech → classify → validate → edit → save pipeline), Patterns (stats + phrasing), Onboarding (permission sequencing). Simple screens — Today, Calendar, Settings — use SwiftData `@Query` directly in the view; no pass-through ViewModels.

**3. Views, dumb by design.** The schema-driven `FieldControl` is the model case: it renders whatever the config says and holds no logic. Theme tokens flow through `Environment`.

**Folder layout — by feature, not by layer:**

```
Ebb/
  App/            // entry point, root tabs, DI wiring
  Models/         // SymptomEntry, SchemaConfig (+ symptom-schema.json)
  DesignSystem/   // Theme tokens, FieldControl, phase ring, cards
  Services/       // SymptomClassifier, SpeechCapture, CycleService, Entitlements, StatsEngine
  Features/
    Today/  Log/  Calendar/  Patterns/  Settings/  Onboarding/  Paywall/  Export/
```

When the Android port happens, everything that travels (schema, prompt, theme tokens, stats logic) is already isolated from everything that doesn't (views).

**Deliberate non-abstraction:** SwiftData models are the single source of truth and CloudKit sync stays invisible behind them. No repository layer over SwiftData "in case the database changes" — it won't, and the abstraction breaks `@Query`.

---

## Phase 0 — Foundations (the two platform-neutral IP layers, in code)

Everything else hangs off these. No visible UI yet beyond a debug screen.

1. **Schema config as a bundled resource.** Convert Part 1 of the classification spec into `symptom-schema.json` shipped in the app bundle, with a Swift loader (`SchemaConfig`, `Field`, `FieldValue` types, `schemaVersion`). This single file must drive *both* the UI controls and (later) the model vocabulary — never duplicate the enums in Swift.
2. **Data model.** SwiftData `SymptomEntry`: timestamp, `schemaVersion`, a dictionary of field-key → value(s) validated against the schema, the verbatim transcript (`note`), and derived `cyclePhase`. Design it CloudKit-compatible from day one (optional fields, no unique constraints CloudKit can't handle).
3. **Theme-tokens layer.** One `Theme` type with the 11 role tokens found in the palettes file (`base, surface, line, text, muted, pain, paindim, onpain, cycle, cycdim, ok`), six theme instances with the exact hexes from `symptom-tracker-palettes.html`, injected via SwiftUI `Environment`. No screen ever hardcodes a color.
4. **Project housekeeping.** Raise the deployment target as needed (Foundation Models requires a recent iOS), organize target folders (`Models`, `Theme`, `Screens`, `Components`, `Services`), keep the TestFlight workflow green.

**Done when:** a debug screen renders every schema field as text and swatches for every theme, and a `SymptomEntry` round-trips through SwiftData.

## Phase 1 — Design system & schema-driven controls

The reusable pieces every screen shares, built to the UI board.

1. **Field controls rendered from the schema:** toggle (`boolean`), 1–5 / 0–5 segmented stepper (`scale`), single-select pills (`enum`), multi-select pills (`multi_enum`) — one generic `FieldControl(field:)` view, not one view per field.
2. **`appliesWhen` progressive disclosure** (hide migraine sub-fields when no migraine, etc.).
3. **Shared components:** cycle phase ring (the signature element), entry card, section headers, the warm-accent = pain / cool-accent = cycle color rule enforced through tokens only.
4. **Tab scaffold:** Today · Calendar · Patterns · Settings, plus the log entry points.

**Done when:** adding a new value to `symptom-schema.json` makes a new pill appear with zero Swift changes.

## Phase 2 — Tap logging (manual path, end-to-end)

Prove "the buttons are the schema" before any AI exists.

1. **Tap screen:** full symptom chart, nothing pre-filled, save → validated `SymptomEntry`.
2. **Today screen:** phase ring (placeholder phase until Phase 4), plain-language day summary (template-driven from the entry data), recent entries, equal-weight Talk / Tap buttons (Talk disabled for now).
3. **Edit / history:** open a saved entry, fix it, delete it (roadmap item §7 of the spec — cheap to do now, painful later).
4. **Empty states** for first-run with no data.

**Done when:** you can live on the app as a manual tracker. This is the first personally usable TestFlight build.

## Phase 3 — Calendar

1. Month view (default) with luteal tint, migraine dots, logged period (filled) vs predicted (dashed); Week toggle.
2. Tap a day → its entries (reusing the entry card + edit flow from Phase 2).

## Phase 4 — HealthKit cycle integration

The hormonal-correlation backbone; still no AI.

1. Read menstrual-flow (and optionally cycle) data from HealthKit; write nothing in v1.
2. **Cycle-phase derivation service:** compute menstrual / follicular / ovulation / luteal from last period start + typical cycle length (user-set fallback in Settings when HealthKit is empty). Stamp `cyclePhase` on every entry at save time.
3. Feed the real phase into the Today ring and the Calendar tints/predictions.
4. Settings: HealthKit connection status + what's shared; cycle info (typical length, aura yes/no).

**Done when:** an entry logged today is automatically tagged with the correct phase, and the calendar predicts the next period.

## Phase 5 — Voice capture (Talk screen)

Transcription only — decoupled from classification so each can be tested alone.

1. **Talk screen** per the UI board: dim, near-empty, breathing orb, live transcript.
2. On-device speech-to-text via the Speech framework (`SFSpeechRecognizer` with `requiresOnDeviceRecognition`, or the newer `SpeechAnalyzer`/`SpeechTranscriber` API where available) — capture must not leave the device.
3. Microphone permission flow + graceful denial (fall back to Tap).
4. Store the verbatim transcript as the entry's `note` (spec: never classified away, kept so the user can re-read their own words).

**Done when:** talking produces a transcript that lands in a draft entry; the user finishes it by tapping (interim UX until Phase 6).

## Phase 6 — Local AI classification + Confirm screen ✦ the hero

**Decision gate first:** verify on-device Apple Foundation Models availability in the EU (Netherlands) on the current iOS. If unavailable → the MLX + bundled Qwen fallback path (same schema, same prompt; only the inference adapter changes).

1. **Prompt assembly:** generate `[ALLOWED_FIELDS]` from `symptom-schema.json` at build/launch time; embed the system prompt + the four few-shot examples from the classification spec.
2. **Classifier service** behind a protocol (`SymptomClassifier`) so Apple-model and MLX/Qwen implementations are swappable. Use **guided generation / constrained decoding** (`@Generable` types generated from the schema) so off-menu output is structurally impossible.
3. **Validation gate:** after the model returns, drop any key/value not in the schema before showing anything (belt-and-suspenders per the spec).
4. **Confirm screen:** raw transcript on top, model-filled pills glowing, everything editable, one tap to fix, explicit save. Every AI-classified entry passes through it — no silent saves.
5. **Test harness:** a unit-test suite that runs the few-shot failure modes (multi-field decomposition, negation, synonyms/foreign words, ambiguity → `{}`) plus a growing list of real utterances; grow the schema's synonym lists from real misses.

**Done when:** "dull one on the right, barely there, worse when I move" pre-selects severity 1, location right, quality dull, worse-with-movement true — and "feeling rough today" pre-selects nothing.

## Phase 7 — Patterns & synthesis

1. **Stats engine (pure Swift, no AI):** migraine frequency by cycle phase, per-cycle clustering, top trigger correlations, relief effectiveness. Deterministic and unit-tested — the app computes the numbers.
2. **Patterns screen:** cycle timeline with migraine clustering, top triggers, plain-language synthesis ("3rd right-side migraine this cycle, all luteal").
3. Phrasing is **template-driven** from the computed stats (the spec flags free-form local-model summaries as the weak spot). Optional cloud-model phrasing is deferred to post-v1, opt-in, Premium.

## Phase 8 — Privacy & data protection

1. **App lock:** Face ID / passcode via `LocalAuthentication`, toggle in Settings.
2. **CloudKit private-database sync** for backup + iPhone↔iPad (no accounts, ever). Test the SwiftData+CloudKit schema early — this is why Phase 0 designed for it.
3. Data export (JSON) as the user-owns-their-data escape hatch.

## Phase 9 — Onboarding, reminders, disclaimers

1. **First-run flow:** the "self-tracking, not diagnostic" disclaimer, HealthKit + microphone + notification permission priming (each asked in context, not all at once), optional typical cycle length + aura status.
2. **Reminders:** luteal-window nudge + optional log reminder via local notifications.
3. About screen with the disclaimer; medications list in Settings (pre-fills the relief pills on Confirm).

## Phase 10 — Monetization (Ebb+)

Per the business plan: never gate logging, the privacy features, or the default theme.

1. **StoreKit 2:** monthly €3.99 / annual €24.99 (anchor, 7-day trial) / lifetime €59.99; entitlement layer + restore.
2. **Gates:** advanced patterns & predictions, full history beyond ~3 cycles, all themes beyond default, (later) cloud summaries.
3. **Contextual paywall** from `symptom-tracker-paywall.html` — shown at payoff moments (opening Patterns, requesting export), never during attack logging.

## Phase 11 — Doctor export ✦ highest-value feature

1. PDF report: cycle↔migraine timeline, frequency by phase, triggers, medications and their effect, date range — designed for a GP/neurologist appointment.
2. Generated fully on-device; share sheet. Premium-gated per the business plan.

## Phase 12 — Hardening & App Store release

1. Accessibility pass (the audience is mid-migraine: Dynamic Type, VoiceOver, reduced motion, dark-by-default verified).
2. Performance (model warm-up, first-token latency on the Confirm flow), offline behavior, migration test for `schemaVersion` bumps.
3. App Review prep: health-data privacy strings, App Privacy "no data collected" labels, medical-disclaimer framing.
4. ASO per the business plan ("menstrual migraine", "hormonal headache tracker"), screenshots, beta cohort feedback → v1 release.

---

## Sequencing rationale & dependencies

- **Schema before UI, UI before AI.** Phases 0–2 make the app usable with zero AI risk; the classifier (Phase 6) then plugs into an already-working Confirm/Tap surface. If the model path stalls (EU availability), everything else still ships.
- **HealthKit (4) before Patterns (7):** the synthesis is worthless without real phase data.
- **Voice (5) is deliberately split from classification (6):** transcription and classification fail differently and must be debugged separately.
- **CloudKit compatibility decided in Phase 0** even though sync lands in Phase 8 — retrofitting a SwiftData model for CloudKit is the most expensive rework in this plan.
- **Monetization late (10)** but the entitlement seams (history window, theme unlock, patterns gate) are cheap to respect from the moment those features are built — keep a single `Entitlements` check point from Phase 3 onward.

## Open decisions to resolve along the way

| When | Decision |
|---|---|
| Before Phase 6 | Apple Foundation Models EU availability → Apple path vs MLX+Qwen bundled path |
| Phase 1 | Exact deployment target (Foundation Models requirement vs device reach) |
| Phase 10 | Are themes free or Ebb+ (spec leaves it open; business plan says Ebb+) |
| Post-v1 | Optional cloud AI summaries (opt-in, Premium, explicit consent) |
