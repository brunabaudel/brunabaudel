# Ebb

A privacy-first, on-device menstrual-migraine and period symptom tracker.

See `../docs/ebb-build-plan.md` for the phased plan and architecture, and
`../docs/symptom-tracker-classification-spec.md` for the schema that drives
both the UI and (later) the on-device classifier.

## Requirements

- Xcode 16+
- iOS 17.0+

## Structure

```
Ebb/
  App/            entry point, root view, DI wiring
  Models/         SymptomEntry, SchemaConfig, FieldValue, symptom-schema.json
  DesignSystem/   Theme tokens, FieldControl, phase ring, entry card
  Features/       Today, Calendar, Patterns, Settings, Log, Debug
EbbTests/         Swift Testing unit tests
```

## Run locally

1. Open `Ebb.xcodeproj` in Xcode
2. Select an iPhone simulator or device
3. Press **Run** (⌘R)

## Tests

```sh
xcodebuild test \
  -project Ebb.xcodeproj \
  -scheme Ebb \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

## Deploy to your iPhone (TestFlight)

1. Add GitHub secrets/variables (see [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md))
2. Go to **Actions → TestFlight → Run workflow**
3. Install **Ebb** from the TestFlight app on your iPhone
