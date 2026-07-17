# Symptom Tracker — Classification Spec v0.1

*The single platform-neutral source of truth. One config defines the **buttons** (UI) and the **allowed values** (model). This file is the IP that travels — it survives iOS→Android and Apple-model→Qwen.*

Scope for v0.1: **menstrual migraine + period symptoms together** (the hormonal-trigger correlation is the whole point, so they share one entry). Cycle phase is *derived* from HealthKit, never entered.

---

## Part 1 — The schema (buttons = allowed values)

One config. The UI renders a control per field from `type` + `values`. The model receives the same `key`s and `synonyms` as its allowed vocabulary. They cannot drift because they're the same source.

```json
{
  "schemaVersion": "0.1.0",
  "domain": "menstrual-migraine-and-period",
  "entry": {
    "timestamp": "auto",
    "cyclePhase": "derived_from_healthkit"
  },
  "fields": [
    {
      "key": "migraine_present",
      "label": "Migraine / headache",
      "type": "boolean",
      "required": true,
      "meaning": "Whether a headache or migraine is present in this entry."
    },
    {
      "key": "severity",
      "label": "Severity",
      "type": "scale",
      "range": [1, 5],
      "labels": { "1": "barely there", "2": "mild", "3": "moderate", "4": "severe", "5": "disabling" },
      "appliesWhen": "migraine_present == true"
    },
    {
      "key": "location",
      "label": "Location",
      "type": "multi_enum",
      "appliesWhen": "migraine_present == true",
      "values": [
        { "key": "right",      "label": "Right side",       "synonyms": ["right", "right-sided", "r side"] },
        { "key": "left",       "label": "Left side",        "synonyms": ["left", "left-sided"] },
        { "key": "bilateral",  "label": "Both sides",       "synonyms": ["both sides", "all over", "whole head", "everywhere"] },
        { "key": "behind_eye", "label": "Behind the eye",   "synonyms": ["behind eye", "behind my eye", "eye socket", "around the eye"] },
        { "key": "temple",     "label": "Temple",           "synonyms": ["temple", "side of the head"] },
        { "key": "forehead",   "label": "Forehead",         "synonyms": ["forehead", "front of head"] },
        { "key": "jaw",        "label": "Jaw / teeth",      "synonyms": ["jaw", "teeth", "mandible", "mandíbula"] },
        { "key": "neck",       "label": "Neck",             "synonyms": ["neck", "base of skull"] }
      ]
    },
    {
      "key": "quality",
      "label": "Pain quality",
      "type": "multi_enum",
      "appliesWhen": "migraine_present == true",
      "values": [
        { "key": "throbbing", "label": "Throbbing", "synonyms": ["throbbing", "pulsing", "pounding"] },
        { "key": "dull",      "label": "Dull",      "synonyms": ["dull", "aching"] },
        { "key": "sharp",     "label": "Sharp",     "synonyms": ["sharp", "stabbing", "shooting"] },
        { "key": "pressure",  "label": "Pressure",  "synonyms": ["pressure", "tight", "squeezing"] }
      ]
    },
    {
      "key": "worse_with_movement",
      "label": "Worse with movement",
      "type": "boolean",
      "appliesWhen": "migraine_present == true"
    },
    {
      "key": "aura",
      "label": "Aura",
      "type": "multi_enum",
      "appliesWhen": "migraine_present == true",
      "values": [
        { "key": "none",    "label": "No aura",                       "synonyms": ["no aura", "none"] },
        { "key": "visual",  "label": "Visual (lights, zigzags, spots)","synonyms": ["flashing lights", "zigzag", "blind spot", "spots", "aura"] },
        { "key": "sensory", "label": "Tingling / numbness",           "synonyms": ["tingling", "numbness", "pins and needles"] },
        { "key": "speech",  "label": "Speech / word-finding",         "synonyms": ["slurred", "can't find words"] }
      ]
    },
    {
      "key": "associated_symptoms",
      "label": "Other symptoms",
      "type": "multi_enum",
      "values": [
        { "key": "nausea",            "label": "Nausea",            "synonyms": ["nausea", "queasy", "sick to my stomach"] },
        { "key": "vomiting",          "label": "Vomiting",          "synonyms": ["vomiting", "threw up", "puked"] },
        { "key": "light_sensitivity", "label": "Light sensitivity", "synonyms": ["light hurts", "sensitive to light", "photophobia", "light is killing me"] },
        { "key": "sound_sensitivity", "label": "Sound sensitivity", "synonyms": ["sound hurts", "noise", "phonophobia"] },
        { "key": "smell_sensitivity", "label": "Smell sensitivity", "synonyms": ["smells", "odors", "sensitive to smell"] }
      ]
    },
    {
      "key": "triggers",
      "label": "Possible triggers",
      "type": "multi_enum",
      "values": [
        { "key": "poor_sleep",      "label": "Poor sleep",          "synonyms": ["bad sleep", "slept badly", "didn't sleep", "little sleep"] },
        { "key": "skipped_meal",    "label": "Skipped meal",        "synonyms": ["skipped a meal", "didn't eat", "hungry", "low blood sugar"] },
        { "key": "stress",          "label": "Stress",              "synonyms": ["stress", "stressed", "anxious"] },
        { "key": "stress_letdown",  "label": "Stress let-down",     "synonyms": ["after a stressful week", "let down", "weekend crash"] },
        { "key": "dehydration",     "label": "Dehydration",         "synonyms": ["dehydrated", "didn't drink", "not enough water"] },
        { "key": "alcohol",         "label": "Alcohol",             "synonyms": ["alcohol", "wine", "drinks", "drinking"] },
        { "key": "caffeine_change", "label": "Caffeine change",     "synonyms": ["skipped coffee", "no coffee", "too much coffee"] },
        { "key": "weather",         "label": "Weather",             "synonyms": ["weather", "pressure change", "storm"] },
        { "key": "bright_light",    "label": "Bright light / screens","synonyms": ["screen", "bright light", "sun", "screens"] }
      ]
    },
    {
      "key": "bleeding",
      "label": "Bleeding",
      "type": "enum",
      "values": [
        { "key": "none",     "label": "None",     "synonyms": ["no period", "not bleeding"] },
        { "key": "spotting", "label": "Spotting", "synonyms": ["spotting", "just a little"] },
        { "key": "light",    "label": "Light",    "synonyms": ["light"] },
        { "key": "medium",   "label": "Medium",   "synonyms": ["medium", "normal", "regular"] },
        { "key": "heavy",    "label": "Heavy",    "synonyms": ["heavy", "soaking", "a lot"] }
      ]
    },
    {
      "key": "cramps_severity",
      "label": "Cramps",
      "type": "scale",
      "range": [0, 5],
      "labels": { "0": "none", "1": "barely there", "2": "mild", "3": "moderate", "4": "severe", "5": "disabling" }
    },
    {
      "key": "relief_taken",
      "label": "Medication / relief",
      "type": "multi_enum",
      "values": [
        { "key": "ibuprofen",     "label": "Ibuprofen",      "synonyms": ["ibuprofen", "brufen", "advil"] },
        { "key": "naproxen",      "label": "Naproxen",       "synonyms": ["naproxen", "aleve"] },
        { "key": "paracetamol",   "label": "Paracetamol",    "synonyms": ["paracetamol", "acetaminophen", "tylenol"] },
        { "key": "triptan",       "label": "Triptan",        "synonyms": ["triptan", "sumatriptan", "imitrex"] },
        { "key": "rest_dark_room","label": "Rest / dark room","synonyms": ["lay down", "dark room", "rested"] },
        { "key": "cold_pack",     "label": "Cold pack",      "synonyms": ["ice", "cold pack", "cold compress"] },
        { "key": "caffeine",      "label": "Caffeine",       "synonyms": ["coffee", "caffeine"] }
      ]
    },
    {
      "key": "relief_effect",
      "label": "Did it help?",
      "type": "enum",
      "appliesWhen": "relief_taken not empty",
      "values": [
        { "key": "none",    "label": "No relief" },
        { "key": "partial", "label": "Some relief" },
        { "key": "full",    "label": "Full relief" }
      ]
    }
  ],
  "freeNote": {
    "key": "note",
    "store": "verbatim_transcript",
    "description": "Raw user utterance, stored on-device only. Never classified into enums — kept so the user can re-read their own words."
  }
}
```

**Field `type` → UI control mapping**

| `type`       | UI control                        | Model output      |
|--------------|-----------------------------------|-------------------|
| `boolean`    | single toggle                     | `true` / `false`  |
| `scale`      | 1–5 (or 0–5) stepper / segmented  | integer           |
| `enum`       | single-select pills               | one value `key`   |
| `multi_enum` | multi-select pills                | array of `key`s   |

`appliesWhen` is for progressive disclosure only (hide period-irrelevant fields when there's no migraine, etc.). It's a UI hint, not a validation rule.

---

## Part 2 — System prompt

Everything in `[ALLOWED_FIELDS]` is generated from Part 1 at build time (keys, labels, value keys, synonyms) so the prompt and the buttons can never disagree.

```
You are a symptom-logging classifier running on-device inside a health app.
The user describes how they feel in plain language. Your only job is to map
what they ACTUALLY said onto the fixed fields and allowed values below, and
return JSON. You do not interpret, diagnose, advise, or add anything the user
did not say.

OUTPUT
- Return ONLY a JSON object. No prose, no markdown, no code fences.
- Use the exact field keys and value keys listed. Never invent a key or value.
- multi_enum fields → array of value keys. enum → one value key.
  boolean → true/false. scale → an integer in range.

CORE RULES
1. Only set a field if the user clearly expressed it. If something isn't
   mentioned, OMIT the field entirely. Unset is always safe; guessing is not.
   The user confirms or fills the rest by tapping — your job is to catch what
   was said, not to complete the form.
2. Handle negation. "no nausea", "wasn't sensitive to light", "didn't take
   anything" mean do NOT add that value. For a boolean, set it false. Never
   log a symptom the user denied.
3. One sentence can map to several fields. Decompose it fully.
   "dull one on the right, worse when I move" →
   location:["right"], quality:["dull"], worse_with_movement:true.
4. Map synonyms and informal or non-English words to the closest allowed key
   (e.g. "pounding"→throbbing, "mandíbula"→jaw). If a word has no clear match,
   OMIT it — do not force the nearest pill.
5. Severity / cramps words → numbers: "barely there"→1, "mild"→2,
   "moderate"→3, "bad"/"severe"→4, "can't function"/"worst ever"→5.
6. If the user mentions a headache at all, set migraine_present:true. If they
   describe only period symptoms with no headache, omit migraine_present's
   dependent fields.
7. If nothing maps cleanly (e.g. "feeling rough today"), return {} and let the
   user fill it in by hand. An empty object is a valid, correct answer.

ALLOWED FIELDS
[ALLOWED_FIELDS]   ← injected from the schema config at build time
```

> On Apple Foundation Models / MLX, pair this with **constrained decoding**: force valid JSON and restrict generation to the allowed keys, so malformed or off-menu output is structurally impossible. The prompt sets intent; constrained decoding enforces it. The **confirm tap** is the final human safety net.

---

## Part 3 — Few-shot examples

Two or three of these in-context lift accuracy sharply. These four deliberately cover the failure modes worth testing: **multi-field decomposition, negation, synonyms/foreign words, and pure ambiguity → empty**.

**1. Multi-field + implication + synonym**
```
User: "dull one on the right, barely there, worse when I move"
{
  "migraine_present": true,
  "severity": 1,
  "location": ["right"],
  "quality": ["dull"],
  "worse_with_movement": true
}
```

**2. Negation + multi-location (severity not stated → omitted)**
```
User: "pounding behind my left eye, the light is killing me but no nausea"
{
  "migraine_present": true,
  "location": ["left", "behind_eye"],
  "quality": ["throbbing"],
  "associated_symptoms": ["light_sensitivity"]
}
```
*nausea was denied → omitted. No severity word was used → omitted, not guessed.*

**3. Period + trigger + relief with partial effect (foreign word handled)**
```
User: "heavy period, cramps são fortes, tomei dois ibuprofeno e ajudou um pouco. dormi mal também"
{
  "bleeding": "heavy",
  "cramps_severity": 4,
  "relief_taken": ["ibuprofen"],
  "relief_effect": "partial",
  "triggers": ["poor_sleep"]
}
```
*"são fortes"→severe→4, "ajudou um pouco"→partial, "dormi mal"→poor_sleep. No migraine mentioned → migraine fields omitted.*

**4. Pure ambiguity → empty object**
```
User: "feeling rough today"
{}
```
*Nothing maps to a defined field. Returning {} and letting the user tap is correct — never invent a severity or symptom to fill the silence.*

---

## Notes for whoever implements this

- **Validation gate.** After the model returns, validate every key/value against this schema and drop anything off-menu before showing pre-filled buttons. Belt-and-suspenders with constrained decoding.
- **`schemaVersion` travels with every saved entry.** When the enum set grows, old entries still resolve correctly, and the Android port reads the same versioned config.
- **Synonyms are model-only.** They never render as buttons; they exist purely to widen what the classifier recognizes. Grow this list from real misses during testing.
- **Adding a symptom = editing this file only.** New pill + synonyms here → it appears in the UI and in the model's vocabulary at once. No code change, no drift.
- **Not a diagnostic tool.** Keep the self-tracking framing and the confirm-tap-on-every-AI-entry guardrail from the concept doc.
```
