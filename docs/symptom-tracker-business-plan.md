# Ebb — Business Plan & Monetization

*Voice-first, on-device menstrual-migraine + cycle tracker. Working name “Ebb.” Companion to the product spec and design package.*

Figures dated June 2026. Market numbers carry the usual analyst-estimate caveats; projections are illustrative scenarios with stated assumptions, not forecasts.

---

## 1 · Thesis in one paragraph

Two big categories — migraine trackers and period trackers — both leave the same gap: the **intersection** between them. Migraine Buddy (the category leader, ~4.8M users) tracks attacks well but handles the menstrual link poorly; period apps track cycles but not migraines. Meanwhile the most-used apps in this space have a trust problem — a large share share data with third parties. **Ebb** wins a defensible niche by being three things none of the incumbents are at once: **purpose-built for menstrual migraine**, **voice-first** (talk, and it fills the chart), and **on-device/private by architecture**. Because classification runs on-device, marginal cost per user is ~€0 — so almost every euro of revenue is margin.

---

## 2 · The problem & the gap

- Menstrual migraine is common and disabling. Roughly **50–60% of women with migraine** report a menstrual association; in population studies about **1 in 5 female migraineurs** get migraine in at least half their cycles. A 2024 US survey found ~31% of all women (52.5% of premenopausal) reported migraines around menstruation. This is a large, motivated, recurring-pain population.
- **Logging happens at the worst moment** — mid-attack, light-sensitive, no energy for a tap-heavy form. Every incumbent makes you tap through fields.
- **The cycle link is the insight people actually want** (“is this hormonal? when’s the next one?”) and it’s exactly what the leaders do worst.
- **Privacy anxiety is real and rising** in femtech (post-Roe in the US; EU data-protection scrutiny; public-health bodies in the UK warning about period-app data harvesting in 2025).

**Competitive read:**

| App | Strength | Gap Ebb exploits |
|---|---|---|
| Migraine Buddy | huge user base, doctor-recognized, weather | weak cycle correlation; cloud-synced; cluttered; many taps mid-attack |
| Bearable | flexible, multi-condition correlation | not purpose-built; heavy setup; premium-gated correlation |
| Period apps (Flo, Clue) | cycle prediction, polish | don’t track migraines; data-sharing reputation |
| Ebb | **voice-first capture · cycle-native migraine insight · on-device/private** | — |

---

## 3 · Market sizing

Top-down for context, but the number that matters for a solo indie is the bottoms-up SOM.

- **Femtech (2026):** ~$50–73B depending on definition and source — large, fast-growing (~15–20% CAGR), strong VC interest.
- **Menstrual-health apps (2026):** ~$2.49B, ~20% CAGR to 2035 (Towards Healthcare). Period-tracker apps narrowly defined ~$0.88B (Business Research Insights). North America ≈ 38–42% of share; Europe a meaningful second.
- **Ebb’s slice (SAM):** the menstrual-migraine intersection within iOS users in launch markets (EN-speaking + NL first). Even a low-single-digit share of menstrual-migraine sufferers on iOS is a multi-million-person addressable base.
- **SOM (realistic, see §7):** indie reach is organic-led; the honest near-term target is thousands of paying users, not market share — and the economics work at that scale because COGS ≈ €0.

---

## 4 · Positioning & moat

- **Voice-first capture** — nobody in migraine/period tracking lets you *just talk*. Hardest to copy well (the schema + on-device classification is real engineering you’ve already specced).
- **On-device / private by design** — not a setting, an architecture. A credible, marketable wedge against the data-sharing reputation of the category. “Your intimate health data never leaves your phone.”
- **Purpose-built for the cycle↔migraine link** — the insight people want, surfaced by default.
- **Near-zero marginal cost** — Foundation Models on-device means no per-log API cost (unlike server-LLM competitors), so pricing power and margin are structurally better.
- **Builder-market fit** — iOS-lead skill set (HealthKit, StoreKit, on-device ML, CloudKit) matches exactly what this app needs; you are also a target user.

---

## 5 · Monetization model — Free vs Premium

Principle: **never gate the logging habit or the privacy promise.** Gate the *synthesis and the deliverables*. Logging must stay free and unlimited — gating it kills retention and is poor form for a health tool.

**Free (the habit + the trust)**
- Unlimited talk + tap logging
- Today, Calendar, recent entries
- HealthKit cycle sync
- On-device storage, Face ID lock, **iCloud backup & sync** (safety/privacy never paywalled)
- Default theme
- Basic “this cycle” view

**Premium — “Ebb+” (the payoff)**
- **Advanced patterns & predictions** — trigger correlation, luteal-window risk, forecasting
- **Doctor export (PDF)** — the high-willingness-to-pay feature; the reason to convert before an appointment
- **Full history** — free keeps the last ~3 cycles; Premium unlocks everything
- **All themes** — cosmetic upsell, low-friction, on-brand
- **Optional cloud AI summaries** — the one feature with any marginal cost; Premium + explicit consent

---

## 6 · Pricing

Benchmarked to the category (Migraine Buddy $4.99/mo · $29.99/yr; HeadAlly $49.99/yr; period apps ~$30–50/yr):

| Plan | Price | Net after Apple 15%* |
|---|---|---|
| Monthly | €3.99 / mo | €3.39 |
| **Annual** *(anchor)* | **€24.99 / yr** (~€2.08/mo) · 7-day free trial | €21.24 |
| Lifetime | €59.99 once | €50.99 |

*\*Apple Small Business Program = 15% commission under $1M/yr — you almost certainly qualify, so model 15%, not 30%.*

Why this shape: annual is the value anchor and the trial home. **Lifetime is unusually attractive here** because marginal cost is ~€0 — you take cash up front, eliminate churn risk on that cohort, and lifetime buyers are often your most loyal evangelists. Keep it; don’t over-discount the annual against it.

---

## 7 · Unit economics & projections

**The structural advantage:** COGS ≈ €0. No server, no per-log inference cost, CloudKit’s free quota is generous, and the only metered feature (cloud summaries) is opt-in and Premium. So contribution margin ≈ **85% of revenue** (just Apple’s cut). Contrast your Yumscan model, which carried per-scan API costs — Ebb has none.

**Illustrative LTV (annual plan):** €21.24 net × ~1.8yr average retention ≈ **€38 LTV**. Lifetime buyers ≈ €51 each. Organic-led acquisition (ASO, community, content) keeps blended CAC low — if held under ~€5–8, LTV:CAC is comfortably healthy.

**Year-1 scenarios** (assumptions stated; ARPU ≈ €22 net blended annual-equivalent):

| Scenario | Downloads (Y1) | Free→paid | Payers | ~Net ARR |
|---|---|---|---|---|
| Conservative | 15,000 | 2.0% | ~300 | ~€6.6k |
| Base | 40,000 | 3.5% | ~1,400 | ~€31k |
| Optimistic | 100,000 | 5.0% | ~5,000 | ~€110k |

Read these as “what would have to be true,” not predictions. Freemium health-app conversion typically lands 2–5%; the doctor-export and predictions features are the levers most likely to push the higher end, because they hit a real moment of need.

---

## 8 · Go-to-market

- **ASO first** — own the long tail: “menstrual migraine,” “hormonal headache tracker,” “period migraine.” The incumbents rank for “migraine” broadly; you win the specific intent.
- **Privacy as the headline** — lead marketing with on-device/private. It differentiates instantly and travels well in a post-Roe, data-wary climate.
- **Community, not ads** — migraine and menstrual-health subreddits, Instagram/TikTok creators in the chronic-illness space, patient forums. Authentic > paid for a solo launch.
- **The doctor angle** — the PDF export is shareable and word-of-mouth-friendly (“I brought this to my neurologist”). Lean into it.
- **You as the story** — a developer who built the tool she needed is a credible, repeatable narrative.

---

## 9 · Paywall strategy

- **Soft, contextual, value-first.** Let people log free and build the habit. Surface the paywall at the *moment of payoff* — when they tap “see your patterns” or “export for doctor” and there’s finally data worth unlocking. Contextual paywalls convert far better than an onboarding hard wall, and they fit the ethic of not blocking logging.
- **7-day free trial on annual**, no card-friction surprises.
- **Pricing screen:** annual highlighted as best value, monthly and lifetime alongside; restore + terms + “cancel anytime.”
- **Don’t paywall mid-migraine.** If someone’s logging an attack, that is never the moment for an upsell — it would damage trust at the worst possible time.
- Tooling: Superwall/StoreKit 2 (already in your stack) for paywall A/B tests without app updates.

→ Paywall screen designed in `symptom-tracker-paywall.html`.

---

## 10 · Risks & mitigations

| Risk | Mitigation |
|---|---|
| Apple ships native cycle/headache logging | Stay ahead on the *voice + synthesis + export* layer; Apple rarely nails niche workflows |
| EU on-device model unavailable (iOS 27) | Fallback to bundled MLX/Qwen — already in the plan |
| Low freemium conversion | Contextual paywall at payoff moments; doctor-export as the hook |
| Niche too narrow for growth | Adjacent expansion later — general migraine, then other cyclical symptoms — *after* owning the wedge |
| “Medical” liability / App Review | Hold the self-tracking-not-diagnostic framing and disclaimers throughout |
| Trust erosion if privacy ever slips | Keep on-device the non-negotiable core; it’s the moat — don’t trade it for a feature |

---

## 11 · Bottom line

A small, defensible niche with a motivated, recurring-need audience; a genuine product wedge (voice + privacy + cycle-native); and **unit economics most indie apps would envy** because the on-device architecture removes COGS. It won’t be a venture-scale company on its own, but as a focused indie product it can be a profitable, low-overhead, high-margin app — and a strong portfolio centerpiece that doubles as proof of your on-device-ML + health + monetization skill set.
