# Symptom Tracker — Product Spec v0.2

*A conversational, on-device health tracker for menstrual migraine + period symptoms. You talk; it fills in the buttons. Nothing leaves your phone.*

Status: concept consolidated. Schema spec drafted, full UI board + palettes + theme picker designed. This document is the single source that ties them together and records the decisions made so far.

---

## 1 · The core idea

Logging happens two ways from one shared data model:

1. **Talk** — the user says something natural (“dull one on the right, barely there, worse when I move”) and an on-device model maps it onto the app’s predefined options, pre-selecting the buttons it thinks the user meant.
2. **Tap** — the user can ignore the talking entirely and tap the buttons themselves.

Both paths produce an **identical structured record**. Voice is a convenience layer over the buttons, not a replacement. A **daily / cycle overview** then summarizes entries in plain language and surfaces patterns (“3rd right-side migraine this cycle, all in the luteal phase”).

---

## 2 · Why it’s different

- Migraine Buddy / Bearable make you tap through fixed fields. This lets you just *talk*, and it does the structuring and the synthesis — same rigor, far less friction, which matters most mid-symptom when you have no energy for a form.
- **Privacy-first by architecture, not policy.** Intimate health + cycle data never touches a server (see §5). Works offline, no per-log API cost.
- Pulls cycle data from **HealthKit** so the hormonal-trigger correlation works without double entry.

---

## 3 · The key architectural insight — the buttons *are* the schema

The model isn’t generating free-form data — it’s **classifying** natural speech into a closed set of enum values (severity 1–5, location {right, left, behind-eye, jaw…}, triggers {poor sleep, skipped meal, stress…}). One config/enum renders the buttons *and* is injected into the model’s system prompt as the allowed values, so UI and model vocabulary can never drift.

This single constraint buys reliability (no field drift), small-model feasibility (classification, not open chat), and graceful degradation (fill what’s caught, leave the rest for a confirm tap).

→ Fully specified in **`symptom-tracker-classification-spec.md`** (schema + system prompt + few-shot examples). That file is the platform-neutral IP that survives every other decision.

---

## 4 · On-device model

Suited to a small on-device model precisely *because* it’s constrained classification.

- **Apple Foundation Models framework** (WWDC 2026): native Swift, free on-device inference, image input, well-suited to structured extraction. New `LanguageModel` protocol gives one interface for Apple’s model, Claude, and Gemini.
- **Constrained decoding** (force valid JSON, restrict tokens to allowed enums) makes malformed output essentially impossible — the key to trusting small-model output for health data. The **confirm tap** is the human safety net.
- **The summary call is the weak spot** for a small local model. Keep it template-driven (app computes the stats, model just phrases them) or route summaries to a cloud model with explicit consent — capture stays local.
- **⚠️ EU caveat (Netherlands):** confirm current iOS 27 availability of the on-device Apple model in the EU before committing. It decides between the Apple-model path and the **MLX + Qwen** bundled path (EU-safe, fully controlled, app-size cost).

---

## 5 · Data & privacy architecture  ✦ decided

The trust story is the product, so the data model is deliberate: **on-device by default, with the user’s own iCloud as the only “cloud.” No accounts.**

**No login / no account.** An email-password account with a server would make *you* the controller of GDPR special-category health data (Article 9) — real liability plus a backend to secure. The app needs none of it to function. This isn’t a missing feature; it’s the point.

**Backup & cross-device → CloudKit private database.** Solves the genuine local-only risk (“lost phone = lost history”) the elegant iOS way: data backs up and syncs across the user’s *own* Apple devices through their Apple ID. You never see it, there’s no login screen, and no privacy compromise. iPhone↔iPad sync for free.

**Privacy lock → LocalAuthentication (Face ID / passcode).** This is what people actually mean by “login” for a health app: a gate so anyone who picks up the phone can’t open the migraine/period log. Fully on-device, no identity, no server. Strongly worth it given how intimate the data is.

| Concern | Answer |
|---|---|
| Identity / account | None — no email, no password, no server |
| Backup & sync | CloudKit **private** DB via the user’s Apple ID (zero-knowledge to us) |
| Privacy gate | Face ID / passcode via `LocalAuthentication` |
| Android-later | Keep “sync” abstracted; Android needs an equivalent (encrypted export / Drive app-data) |

---

## 6 · App map

**Designed** (see `symptom-tracker-ui-design.html`):

1. **Today** — cycle phase ring (the signature), plain-language summary, recent entries, equal-weight Talk / Tap.
2. **Talk** — dim, near-empty capture screen; breathing orb, live transcript.
3. **Confirm** ✦ the hero — raw transcript on top, model-filled pills glowing, one tap to fix; the human-in-the-loop safety net.
4. **Tap** — same chart, nothing pre-filled (manual fallback; proves the buttons *are* the schema).
5. **Patterns** — cycle timeline with migraine clustering, top triggers, plain-language synthesis.
6. **Calendar** — combined Month / Week toggle, **Month default**; luteal tint, migraine dots, logged period (filled) vs predicted (dashed), tap a day for its entries.
7. **Appearance** — theme picker (see §8), in `symptom-tracker-theme-picker.html`.

**Still to design** (§7 roadmap): Onboarding, Profile & Settings, Doctor export, Edit/history, Empty states.

---

## 7 · Roadmap — what’s missing before a real v1

In rough priority:

- **Onboarding / first-run** — prime HealthKit, microphone, and notification permissions; show the “self-tracking, not diagnostic” disclaimer; optionally capture typical cycle length + aura status.
- **Doctor export** ✦ highest-value add — a PDF/summary of the cycle↔migraine pattern to bring to a GP or neurologist. Delivers the concept’s “confirm the pattern for your doctor” promise *and* reinforces that the user owns their data.
- **Reminders** — a gentle nudge entering the high-risk luteal window, or to log sleep; ties directly to the prevention angle.
- **Edit / history** — view and fix a saved entry (the calendar hints at it; no edit flow exists yet).
- **Empty states** — honest, inviting first-week-with-no-data screens.

---

## 8 · Themes  ✦ decided: user-selectable

Color carries meaning here — **warm accent = pain/symptom, cool accent = cycle/hormone** — so that rule holds across every theme; only the hues change. Six palettes, all low-luminance, soft-not-pure-white text (full hexes in `symptom-tracker-palettes.html`):

| Theme | Feel |
|---|---|
| **Plum & Ember** *(default)* | warm plum night, coral + lavender — tender, nocturnal |
| **Tidewater** | deep teal, apricot + sky — health-and-calm |
| **Nocturne** | indigo, blush + periwinkle — night-logging |
| **Ash & Sage** | neutral charcoal, clay + sage — quietest, gender-neutral |
| **Oat & Rose** *(light)* | warm paper, dusty rose + teal — daytime opt-in |
| **Moss & Clay** | earth-brown, clay + moss — grounded, botanical |

**Decisions / open items:**
- **Default = Plum & Ember**, dark. Light themes are opt-in — a bright screen is harder mid-migraine, so dark stays the default.
- **Selection persists** locally (one of the few real “profile” settings).
- Optional **“match device light/dark”** auto-switch that pairs a chosen dark theme with Oat & Rose.
- Implement as a small **theme-tokens layer**: each theme = 7 role tokens (base, surface, line, text, muted, pain-accent, cycle-accent). One selection flows through the whole app — no per-screen recoloring. This is the color companion to the schema: platform-neutral, ports to Android.
- **Open:** free vs. a light paywall lever. Cosmetic themes are a common, non-annoying upgrade in indie health apps and fit the freemium model — decide later.

---

## 9 · Profile & Settings

Framed as *settings + cycle info*, **not an identity**. All local preferences:

- **Appearance** — theme + match-device toggle (§8)
- **App lock** — Face ID / passcode on/off (§5)
- **HealthKit** — connection status, what’s shared
- **Reminders** — luteal-window nudge, log reminders
- **Cycle info** — typical cycle length, aura yes/no (also gates birth-control safety messaging)
- **My medications** — pre-fills the relief pills on the Confirm screen
- **Backup** — iCloud sync status; export / “bring to doctor”
- **About** — the “self-tracking, not diagnostic” disclaimer

---

## 10 · Guardrails

- Positioned explicitly as a **self-tracking tool, not a diagnostic one** (same disclaimer framing established apps use).
- Human-in-the-loop **confirm tap** on every AI-classified entry.
- Health data stays on-device by default; any cloud call (e.g. an optional cloud summary) is opt-in with explicit consent. iCloud backup is the user’s own private database, not ours.

---

## 11 · Build decisions

- **iOS-first, then Android.** Validate the interaction and personal daily use before expanding.
- **Native Swift over React Native** — the hard parts (on-device model, HealthKit, StoreKit, CloudKit, constrained decoding, LocalAuthentication) are native anyway; SwiftUI suits the talk → pre-fill → confirm flow; plays to existing iOS-lead strength.
- **Two platform-neutral IP layers travel to any platform:** the **schema/prompt/few-shot** spec and the **theme tokens**. Both are data/text, not implementation — the expensive-to-design parts survive an Android rewrite; only the UI code gets redone.

---

## 12 · Suggested next steps

1. Confirm EU availability of the on-device Apple model on iOS 27 → picks the model path (§4).
2. The schema spec is the build anchor; wire it to (a) the SwiftUI Confirm-screen pills and (b) the Foundation Models classification call.
3. Stand up the **theme-tokens layer** so the app ships theme-able from day one.
4. Design the remaining screens (§7), starting with **doctor export** (highest value) and **onboarding** (gates permissions + disclaimer).

---

### Appendix · File index

| File | What it is |
|---|---|
| `symptom-tracker-product-spec.md` | this document — the master spec |
| `symptom-tracker-classification-spec.md` | schema + system prompt + few-shot examples (the core IP) |
| `symptom-tracker-ui-design.html` | 7-screen UI board |
| `symptom-tracker-palettes.html` | six palette options, applied previews |
| `symptom-tracker-theme-picker.html` | in-app Appearance / theme picker |
