# TestFlight setup

## One-time: register the app with Apple

Before the first CI run, register the bundle ID in [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list):

- **Bundle ID:** `com.brunabaudel.BasicApp`
- **Type:** App

Then create the app in [App Store Connect](https://appstoreconnect.apple.com/) → **Apps** → **+** → **New App**, using the same bundle ID.

## GitHub secrets

| Name | Value |
|------|-------|
| `DEVELOPMENT_TEAM` | `3F274MB2RL` |
| `APPSTORE_API_PRIVATE_KEY` | Full `.p8` file contents (include `BEGIN`/`END` lines) |

## GitHub variables

| Name | Value |
|------|-------|
| `APPSTORE_ISSUER_ID` | `0db26431-c329-43ec-a88a-7726ac48b535` |
| `APPSTORE_API_KEY_ID` | `L2WA39JRT9` |

Add these under **Settings → Secrets and variables → Actions**.

## Deploy

1. Go to **Actions → TestFlight → Run workflow**
2. Wait for the build (~10–15 min)
3. Open **TestFlight** on your iPhone and install **BasicApp**

## Troubleshooting

| Error | Fix |
|-------|-----|
| `invalid curve name` / missing `BEGIN PRIVATE KEY` | Re-paste the `.p8` secret with correct newlines |
| `No profiles for com.brunabaudel.BasicApp` | Register the bundle ID in Apple Developer portal |
| `App not found` | Create the app in App Store Connect |
