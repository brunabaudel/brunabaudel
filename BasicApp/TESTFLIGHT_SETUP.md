# TestFlight setup

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

## One-time: create the app in App Store Connect

Your API key can upload builds but cannot create new apps. Do this once in your browser:

1. Open [App Store Connect → Apps](https://appstoreconnect.apple.com/apps)
2. Click **+** → **New App**
3. Platform: **iOS**
4. Name: **BasicApp**
5. Bundle ID: **com.brunabaudel.BasicApp** (create the identifier first if needed)
6. SKU: **basicapp001**
7. Click **Create**

## Deploy

1. Go to **Actions → TestFlight → Run workflow**
2. Wait for the build (~10–15 min)
3. Open **TestFlight** on your iPhone and install **BasicApp**

First upload may take an extra 10–30 minutes for Apple to process.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `No suitable application records were found` | Create the app in App Store Connect (step above) |
| `missing BEGIN PRIVATE KEY` | Re-paste the `.p8` secret with correct newlines |
| Build fails on signing | Confirm bundle ID `com.brunabaudel.BasicApp` exists in Apple Developer |
