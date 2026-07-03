# TestFlight via GitHub Actions

Install **BasicApp** on your iPhone using GitHub Actions + TestFlight. After a short one-time setup, you never need a Mac.

## What you need to do (about 10 minutes)

I cannot log into your Apple or GitHub accounts, but you only need to do **two things**:

### 1. Create an App Store Connect API key (in your browser)

1. Open [App Store Connect → Users and Access → Integrations → API](https://appstoreconnect.apple.com/access/integrations/api)
2. Click **+** to generate a key with **Admin** or **App Manager** access
3. Download the `.p8` file (only available once)
4. Copy your **Issuer ID** and **Key ID** from the same page
5. Copy your **Team ID** from [Apple Developer → Membership](https://developer.apple.com/account#MembershipDetailsCard)

### 2. Configure GitHub (copy/paste once)

On any computer with the [GitHub CLI](https://cli.github.com/) installed:

```bash
cd BasicApp/scripts
cp setup-secrets.env.example setup-secrets.env
# Edit setup-secrets.env with your Team ID, Issuer ID, Key ID, and .p8 contents

chmod +x configure-github-secrets.sh
./configure-github-secrets.sh
```

That script stores everything in GitHub secrets/variables for you. **No Mac, no certificates, no provisioning profiles to export manually** — Fastlane creates those in CI using your API key.

---

## Deploy to your iPhone

1. Merge this branch (or push to `app/ebb` / `main`)
2. Go to **Actions → TestFlight → Run workflow**
3. First time only: choose **setup-app** to register the bundle ID and App Store Connect app
4. Run again with **deploy** to build and upload to TestFlight
5. Open the **TestFlight** app on your iPhone and install **BasicApp**

> First upload may take 10–30 minutes for Apple to process.

---

## GitHub secrets (set automatically by the script)

| Name | Type | Description |
|------|------|-------------|
| `DEVELOPMENT_TEAM` | Secret | 10-character Apple Team ID |
| `APPSTORE_API_PRIVATE_KEY` | Secret | Full `.p8` file contents |
| `KEYCHAIN_PASSWORD` | Secret | Random string (auto-generated) |
| `APPSTORE_ISSUER_ID` | Variable | From App Store Connect API page |
| `APPSTORE_API_KEY_ID` | Variable | Key ID from App Store Connect API |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Authentication credentials are missing or invalid` | Re-check Issuer ID, Key ID, and `.p8` contents in `setup-secrets.env` |
| `No value found for 'DEVELOPMENT_TEAM'` | Run `configure-github-secrets.sh` again |
| `App not found` in App Store Connect | Run workflow with **setup-app** first |
| Build not in TestFlight yet | Wait for Apple processing; check App Store Connect → TestFlight |

---

## How it works

Fastlane runs on GitHub’s macOS runners and:

1. Creates a distribution certificate and App Store profile (via your API key)
2. Builds and signs the app
3. Uploads to TestFlight

Workflow: [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml)
