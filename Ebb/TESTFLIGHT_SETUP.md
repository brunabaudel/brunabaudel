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

Your **Admin** API key is correct for uploading builds. Apple simply does not allow creating new app records via the API — that step must be done in the browser once.

## One-time: create the app in App Store Connect (done)

The app record exists as **Ebbie** (the name "Ebb" was already taken on the App Store).
The App Store Connect name is independent of the bundle ID and the on-device display
name — CI matches builds by bundle ID only.

1. Open [App Store Connect → Apps](https://appstoreconnect.apple.com/apps)
2. Click **+** → **New App**
3. Platform: **iOS**
4. Name: **Ebbie**
5. Bundle ID: **com.bcbs.ebb**
6. SKU: **ebb001**
7. Click **Create**

## Deploy

1. Go to **Actions → TestFlight → Run workflow** (or push to `app/ebb` touching `Ebb/**`)
2. Wait for the build (~10–15 min)
3. Open **TestFlight** on your iPhone and install **Ebbie**

First upload may take an extra 10–30 minutes for Apple to process.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `No App Store Connect app found` | Create the app in App Store Connect (step above) |
| `No suitable application records were found` | Same — the app record must exist before upload |
| `missing BEGIN PRIVATE KEY` | Re-paste the `.p8` secret with correct newlines |
