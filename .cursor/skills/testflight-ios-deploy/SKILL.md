---
name: testflight-ios-deploy
description: Deploy an iOS app to TestFlight and manage beta groups/testers entirely through CI and the App Store Connect API, without opening App Store Connect in a browser. Use when setting up or debugging TestFlight uploads, beta groups, tester invites, code signing in GitHub Actions, or Spaceship/fastlane API scripts for this repo.
---

# TestFlight deploy and beta group management via API

This repo ships the `Ebb` iOS app to TestFlight from GitHub Actions with zero
manual App Store Connect (ASC) steps after a one-time app-record creation.
Everything is driven by an ASC API key and small Ruby scripts using Spaceship
(the API client library inside the `fastlane` gem — fastlane lanes/Fastfile
are NOT used).

## Working configuration

| Piece | Location |
|-------|----------|
| Workflow | `.github/workflows/testflight.yml` |
| Bundle ID registration | `Ebb/ci/register_bundle_id.rb` |
| App record existence check | `Ebb/ci/verify_app_store_connect_app.rb` |
| Beta group + testers | `Ebb/ci/create_beta_group.rb` |
| Export options | `Ebb/ExportOptions.plist` (`app-store-connect`, manual signing) |
| Certificate cleanup | `Ebb/ci/prune_ephemeral_certificates.rb` |
| Provisioning profile | `Ebb/ci/ensure_app_store_profile.rb` |
| Signing import | `.github/actions/setup-apple-signing` |

GitHub **secrets**: `DEVELOPMENT_TEAM` (Apple team ID), `APPSTORE_API_PRIVATE_KEY`
(full `.p8` contents including BEGIN/END lines), `BUILD_CERTIFICATE_BASE64` (one
Apple Distribution `.p12`), `P12_PASSWORD`, `KEYCHAIN_PASSWORD`.
GitHub **variables**: `APPSTORE_ISSUER_ID`, `APPSTORE_API_KEY_ID`.
The API key has the **Admin** role.

Pipeline order (job `deploy-testflight`, `macos-26` runner):

1. Write the `.p8` key to `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`
   (Spaceship and xcodebuild both read it from there) and validate it contains
   `BEGIN PRIVATE KEY`.
2. `agvtool new-version -all $GITHUB_RUN_NUMBER` — monotonically increasing
   build numbers with no state in the repo.
3. Register bundle ID (idempotent), verify the ASC app record exists.
4. **Prune ephemeral certificates** — revoke API-created development certs and
   keep one IOS_DISTRIBUTION cert on the Apple account.
5. Create the internal beta group and add testers (idempotent).
6. Import the single Apple Distribution `.p12` from `BUILD_CERTIFICATE_BASE64`
   into a temporary keychain.
7. Ensure/download the App Store provisioning profile for `com.bcbs.ebb`.
8. `xcodebuild archive` + `-exportArchive` with `CODE_SIGN_STYLE=Manual` and
   **no** `-allowProvisioningUpdates` — reuses the stored cert every run.
9. Upload with `apple-actions/upload-testflight-build@v3`.

Auth boilerplate shared by all scripts:

```ruby
require "spaceship"
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch("APPSTORE_API_KEY_ID"),
  issuer_id: ENV.fetch("APPSTORE_ISSUER_ID"),
  filepath: File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{ENV.fetch('APPSTORE_API_KEY_ID')}.p8")
)
```

## Hard-won API facts (verified against live runs, fastlane 2.236.1)

1. **App records cannot be created via the API**, even with an Admin key.
   Creating the app (name, SKU, bundle ID) is a one-time browser step. The
   ASC app name ("Ebbie") is independent of the bundle ID and display name;
   everything matches by bundle ID (`com.bcbs.ebb`).

2. **Spaceship's `App#create_beta_group` is broken for internal groups.**
   It always sends `publicLinkEnabled`/`publicLinkLimit*` attributes and Apple
   rejects them: "Public link limit cannot be applied to internal group".
   Post the request directly instead:

```ruby
body = {
  data: {
    type: "betaGroups",
    attributes: { name: GROUP_NAME, isInternalGroup: true, hasAccessToAllBuilds: true },
    relationships: { app: { data: { type: "apps", id: app.id } } }
  }
}
Spaceship::ConnectAPI.client.test_flight_request_client.post("v1/betaGroups", body)
```

3. **`BetaGroup#post_bulk_beta_tester_assignments` fails with API-key auth** —
   `/v1/bulkBetaTesterAssignments` is a private ASC-web endpoint ("The URL
   path is not valid"). Use the documented endpoint instead:

```ruby
Spaceship::ConnectAPI.post_beta_tester_assignment(
  beta_group_ids: [group.id],
  attributes: { email: "...", firstName: "...", lastName: "..." }
)
```

4. **Internal vs external groups.** Internal groups (`isInternalGroup: true`)
   skip Beta App Review, and with `hasAccessToAllBuilds: true` every uploaded
   build is distributed automatically — no per-build assignment. But testers
   must be ASC **team members** (inviting new team members requires the
   browser). External groups accept anyone and support public invite links
   (`publicLinkEnabled`), but the first build needs Beta App Review (hours to
   a day) and each build must be assigned via `Build#add_beta_groups`.

5. **Export compliance**: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
   is set in `project.pbxproj`, so builds never get stuck on
   "Missing Compliance".

6. **App Store uploads require the current iOS SDK** — hence the `macos-26`
   runner (Xcode 26). Older runner images get rejected by Apple.

7. **Do not use automatic signing in CI.** `-allowProvisioningUpdates` on
   ephemeral GitHub runners creates a new IOS_DEVELOPMENT certificate every run,
   hits Apple's certificate limit, and archives fail with "Choose a certificate
   to revoke." Use one Apple Distribution `.p12` in `BUILD_CERTIFICATE_BASE64`
   and manual signing instead.

8. Idempotency pattern used everywhere: find first, create only if missing,
   exit 0 either way — every deploy re-runs all setup steps safely.

## Operational notes

- Testers get one TestFlight email invite; after accepting, new builds appear
  automatically (internal group). Add testers by appending to the `TESTERS`
  array in `Ebb/ci/create_beta_group.rb`.
- The workflow triggers on push to `app/ebb`/`main` touching `Ebb/**` or the
  workflow file, plus `workflow_dispatch`. Pushes run **Capture screenshots**
  and **Deploy to TestFlight** in parallel. Manual runs expose two booleans:
  `capture_screenshots` and `deploy_testflight` (screenshots-only ~5 min,
  TestFlight-only ~3 min, both ~8 min). PRs run simulator tests + screenshots only.
  Apple's post-upload processing adds 10–30 minutes before the build is
  installable.
- Debug failures with `gh run list --workflow=testflight.yml` and
  `gh run view <id> --log-failed`. Spaceship errors surface Apple's exact
  message (e.g. attribute rejections) in the step log.
- To test Spaceship calls without credentials, generate a throwaway key:
  `OpenSSL::PKey::EC.generate("prime256v1").to_pem` and pass it as `key:` to
  `Token.create` — client wiring can be exercised locally; only the HTTP call
  needs the real key.
