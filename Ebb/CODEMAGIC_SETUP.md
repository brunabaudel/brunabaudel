# Codemagic setup

Codemagic mirrors the GitHub Actions TestFlight pipeline on branch **`app/ebb`**. Two workflows in [`codemagic.yaml`](../codemagic.yaml) at the repo root:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **Ebb — Unit tests** | Push or PR to `app/ebb` (when `Ebb/**` changes) | Simulator unit tests, no signing |
| **Ebb — TestFlight** | Push to `app/ebb` (when `Ebb/**` changes) | Archive, upload to TestFlight, distribute to **Ebb Internal** |

PRs run unit tests only. Pushes run unit tests and TestFlight in parallel (same as GitHub Actions).

## 1. Add the app in Codemagic

1. Sign in at [codemagic.io](https://codemagic.io) and click **Add application**.
2. Connect GitHub repository **`brunabaudel/brunabaudel`**.
3. When asked for configuration, choose **codemagic.yaml** (not the Workflow Editor).
4. Select branch **`app/ebb`** and click **Check for configuration file** — Codemagic should detect `codemagic.yaml`.

## 2. App Store Connect API key (Team integration)

Reuse the same Admin API key as GitHub Actions (see [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md)):

| Field | Value |
|-------|-------|
| Key name in Codemagic | **`ebb`** (must match `integrations.app_store_connect` in `codemagic.yaml`) |
| Issuer ID | `0db26431-c329-43ec-a88a-7726ac48b535` |
| Key ID | `L2WA39JRT9` |
| `.p8` file | Same key as `APPSTORE_API_PRIVATE_KEY` in GitHub |

Steps: **Team settings → Team integrations → Developer Portal → Manage keys → Add key**.

## 3. Code signing identities

Upload the **same** Apple Distribution certificate used for GitHub Actions (see [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md) — export `Ebb-Distribution.p12` once from Keychain Access).

1. **Team settings → codemagic.yaml settings → Code signing identities → iOS certificates**
2. Upload the `.p12`, enter its password, reference name e.g. **`ebb-distribution`**
3. **iOS provisioning profiles → Fetch profiles** (uses the API key above)
4. Select the **App Store** profile for **`com.bcbs.ebb`**, reference name e.g. **`ebb-app-store`**

Codemagic matches certificates and profiles by bundle ID via `ios_signing.distribution_type: app_store` in `codemagic.yaml`. The TestFlight workflow also runs `ci/ensure_app_store_profile.rb` to regenerate the profile when HealthKit or iCloud entitlements change.

> Do **not** let Codemagic generate a new distribution certificate if you already have one — Apple allows only three per account. Upload the existing `.p12`.

## 4. Environment variable group

Create a group named **`ebb_apple_credentials`** (Application or Team settings → Environment variables). Mark secrets as **Secret**.

| Variable | Value | Secret? |
|----------|-------|---------|
| `APP_STORE_CONNECT_PRIVATE_KEY` | Full `.p8` contents (include `BEGIN`/`END` lines) | Yes |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | `L2WA39JRT9` | No |
| `APP_STORE_CONNECT_ISSUER_ID` | `0db26431-c329-43ec-a88a-7726ac48b535` | No |

These feed the existing Ruby scripts (`register_bundle_id.rb`, `ensure_app_store_profile.rb`, `create_beta_group.rb`) via `ci/write_app_store_connect_api_key.sh`.

## 5. Webhook (if builds do not start automatically)

For GitHub repos connected over HTTPS, Codemagic usually installs the webhook automatically. If pushes to `app/ebb` do not trigger builds:

1. Open the app in Codemagic → **Webhooks**
2. Click **Update webhook** (team admin who added the repo)

## 6. First build

1. Push a commit touching `Ebb/**` on branch **`app/ebb`**, or start **Ebb — TestFlight** manually from the Codemagic UI.
2. Wait ~10–15 minutes after upload, then open **TestFlight** on your iPhone and install **Ebbie**.

Build numbers use Codemagic's `BUILD_NUMBER` (same idea as GitHub's `run_number`).

## GitHub Actions vs Codemagic

Both pipelines share the same Ruby scripts and signing material. You can run either or both:

- **GitHub Actions** — `.github/workflows/testflight.yml`, secrets in GitHub
- **Codemagic** — `codemagic.yaml`, credentials in Codemagic UI

## Troubleshooting

| Error | Fix |
|-------|-----|
| `No workflows configured` on PR | Ensure `codemagic.yaml` exists on the **PR source branch** |
| `Missing App Store Connect API credentials` | Add the `ebb_apple_credentials` variable group |
| Integration name mismatch | Rename the Codemagic API key to **`ebb`** or update `integrations.app_store_connect` in `codemagic.yaml` |
| No matching certificate for bundle ID | Upload the `.p12` under Code signing identities; confirm bundle ID is `com.bcbs.ebb` |
| `No valid IOS_DISTRIBUTION certificate` | Re-upload the same `.p12` used in GitHub (`BUILD_CERTIFICATE_BASE64`) |
| iCloud / HealthKit profile errors | Same fixes as [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md) — then re-run TestFlight |
| `No App Store Connect app found` | App record **Ebbie** must exist (one-time step, already done) |

See also [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md) for Apple Developer portal steps and beta group details.
