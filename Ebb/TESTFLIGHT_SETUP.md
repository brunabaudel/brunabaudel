# TestFlight setup

## GitHub secrets

| Name | Value |
|------|-------|
| `DEVELOPMENT_TEAM` | `3F274MB2RL` |
| `APPSTORE_API_PRIVATE_KEY` | Full `.p8` file contents (include `BEGIN`/`END` lines) |
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded **Apple Distribution** `.p12` (one cert only) |
| `P12_PASSWORD` | Password used when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any random string for the temporary CI keychain |

## One-time: export the single Apple Distribution certificate

CI uses **manual signing** with one persistent Apple Distribution certificate stored
in GitHub. Ephemeral runners must not mint new certificates on every run — that
exhausts Apple's per-account certificate limit.

1. Open [Apple Developer → Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Revoke extra **Apple Development** / **Apple Distribution** certificates created
   by CI (names like "Created via API"). Keep **one** valid **Apple Distribution**
   certificate for team `3F274MB2RL`.
3. On your Mac, open **Keychain Access** and export that distribution certificate
   (with private key) as `Ebb-Distribution.p12`.
4. Base64-encode and add repository secrets:

```bash
base64 -i Ebb-Distribution.p12 | pbcopy   # → BUILD_CERTIFICATE_BASE64
openssl rand -base64 32 | pbcopy            # → KEYCHAIN_PASSWORD
```

5. Set `P12_PASSWORD` to the export password you chose in step 3.

The deploy job also runs `ci/prune_ephemeral_certificates.rb` after importing the
`.p12` to revoke leftover API-created development certificates and any extra
distribution certificates that do not match `BUILD_CERTIFICATE_BASE64`, leaving
exactly one Apple Distribution certificate on the account.

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

### Xcode Cloud (Archive → TestFlight)

For a native Apple CI path (no GitHub Actions minutes, managed signing), use the
**Archive TestFlight** workflow. Repo-side scripts and step-by-step setup are in
[XCODE_CLOUD_SETUP.md](XCODE_CLOUD_SETUP.md).

Quick summary: in Xcode, create a workflow on scheme **Ebb** that archives on
push to **`app/ebb`**, prepares for **TestFlight (Internal Testing Only)**, and
post-distributes to the **Ebb Internal** group.

### Automatic (push to `app/ebb`) — GitHub Actions

Every push that touches `Ebb/**` runs **both** jobs in parallel:

- **Capture screenshots** — simulator PNGs + job summary previews
- **Deploy to TestFlight** — archive, upload, distribute to **Ebb Internal**

PRs run **Build & Test (Simulator)** only (unit tests + screenshots, no TestFlight).

### Manual (pick what runs)

1. Go to **Actions → TestFlight → Run workflow**
2. Choose branch **`app/ebb`**
3. Toggle the checkboxes:

| Capture screenshots | Deploy to TestFlight | What runs |
|---|---|---|
| on | on | Both (same as a push) |
| on | off | Screenshots only (~5 min) — no TestFlight upload |
| off | on | TestFlight only (~3 min) — no screenshots |
| off | off | Nothing (workflow succeeds with no jobs) |

4. Click **Run workflow**

For TestFlight installs after a deploy: wait ~10–15 min, then open **TestFlight** on your iPhone and install **Ebbie**.

First upload may take an extra 10–30 minutes for Apple to process.

## Screenshots

CI can capture three simulator screenshots: **Today**, **Tap log**, and **Calendar**.

They run automatically on PRs and on pushes to `app/ebb` (in the **Capture screenshots** job).
On manual runs, toggle **Capture simulator screenshots** in the workflow dispatch form.

**Where to view them:**

1. Open the workflow run on GitHub Actions (e.g. **Actions → TestFlight →** the latest run).
2. Scroll the job log to **App screenshots** in the job summary — previews are inline.
3. Or download the **`screenshots`** artifact at the bottom of the run page (`screenshots.zip`).

Artifacts expire after GitHub’s retention period (~90 days). Screenshots are simulator renders, not from a physical device.

Scripts: `ci/capture_screenshots.sh`, `ci/write_screenshot_summary.sh`.

## Beta group

CI manages an **internal** TestFlight group named **Ebb Internal** — no App
Store Connect access needed. `ci/create_beta_group.rb` (idempotent, runs on
every deploy):

- creates the group with **access to all builds**, so every uploaded build is
  distributed to the group automatically once Apple finishes processing it —
  no Beta App Review, no per-build assignment
- adds `brubaudel@gmail.com` (the account owner) as a tester

The tester receives a TestFlight email invite on first run; after accepting it
once, new builds just appear in the TestFlight app.

Internal groups only accept App Store Connect **team members**. To add more
testers, add their email to the `TESTERS` list in `ci/create_beta_group.rb` —
but they must first be invited to the ASC team (Users and Access), which
requires the browser. For testers outside the team, an external group with a
public link would be needed instead (first build then requires Beta App
Review).

## Troubleshooting

| Error | Fix |
|-------|-----|
| `No App Store Connect app found` | Create the app in App Store Connect (step above) |
| `No suitable application records were found` | Same — the app record must exist before upload |
| `missing BEGIN PRIVATE KEY` | Re-paste the `.p8` secret with correct newlines |
| `maximum number of certificates` | Revoke extra certs in Apple Developer; ensure `BUILD_CERTIFICATE_BASE64` is set so CI stops minting new ones |
| `Missing Apple Distribution certificate secret` | Add `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, and `KEYCHAIN_PASSWORD` (see above) |
| `No valid IOS_DISTRIBUTION certificate found` | Create or restore one Apple Distribution certificate, export `.p12`, update `BUILD_CERTIFICATE_BASE64` |
