# Xcode Cloud: Archive → TestFlight

Xcode Cloud workflows are configured in **Xcode** (or App Store Connect), not as
files in the repo. This document is the exact recipe for the **Archive
TestFlight** workflow for **Ebb**. The supporting `ci_scripts/` in this
directory are already committed.

## Prerequisites

- Apple Developer Program membership (team `3F274MB2RL`)
- App **Ebbie** in App Store Connect with bundle ID `com.bcbs.ebb` (see
  [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md))
- Internal TestFlight group **Ebb Internal** (created by GitHub Actions or
  `ci/create_beta_group.rb`)
- Xcode 15+ on your Mac, signed in with an ASC role that can manage Xcode Cloud
  (Account Holder, Admin, or App Manager)

## 1. Connect the repository

1. Open `Ebb/Ebb.xcodeproj` in Xcode.
2. **Product → Xcode Cloud → Create Workflow…** (or **Integrate → Create
   Workflow…**).
3. Sign in and grant Xcode Cloud access to **GitHub → brunabaudel/brunabaudel**.
4. When asked for the project, confirm:
   - **Project**: `Ebb/Ebb.xcodeproj`
   - **Scheme**: `Ebb`
   - **Bundle ID**: `com.bcbs.ebb`

## 2. Create the workflow

Name the workflow **Archive TestFlight**.

### Start conditions

| Setting | Value |
|---------|-------|
| **Branch Changes** | Enabled |
| Branches | `app/ebb` |
| **Pull Request Changes** | Disabled (use GitHub Actions for PR tests) |
| **Tag Changes** | Disabled |
| **Manual Start** | Enabled (optional — run from Xcode or App Store Connect) |

### Environment

Leave defaults unless signing fails:

| Variable | Value | Notes |
|----------|-------|-------|
| `DEVELOPMENT_TEAM` | `3F274MB2RL` | Only if automatic signing cannot resolve the team |

Xcode Cloud manages certificates and provisioning profiles when the workflow is
linked to App Store Connect.

### Actions

Add these actions **in order**:

#### Action 1 — Test (optional but recommended)

| Setting | Value |
|---------|-------|
| **Platform** | iOS |
| **Scheme** | `Ebb` |
| **Destination** | Any iOS Simulator (e.g. iPhone 16) |
| **Test plan** | Default (runs `EbbTests`) |

Skip this action if you only want the fastest path to TestFlight.

#### Action 2 — Archive

| Setting | Value |
|---------|-------|
| **Platform** | iOS |
| **Scheme** | `Ebb` |
| **Distribution preparation** | **TestFlight (Internal Testing Only)** |

This archives, signs, and uploads the build to App Store Connect.

### Post-actions

Add **TestFlight Internal Testing**:

| Setting | Value |
|---------|-------|
| **Group** | **Ebb Internal** |
| **What to test** | Optional release notes for testers |

With **access to all builds** on that group, new uploads are distributed
automatically once Apple finishes processing (typically 10–30 minutes).

## 3. Save and run

1. Click **Save** (or **Next** through the wizard, then **Save**).
2. Trigger the first build:
   - Push to `app/ebb`, or
   - In Xcode: **Product → Xcode Cloud → Start Build** and pick **Archive
     TestFlight**, or
   - In [App Store Connect → Xcode Cloud](https://appstoreconnect.apple.com),
     start a build manually.

## What the repo provides

| File | Purpose |
|------|---------|
| `ci_scripts/ci_post_clone.sh` | Logs build context after clone |
| `ci_scripts/ci_pre_xcodebuild.sh` | Sets `CURRENT_PROJECT_VERSION` from `CI_BUILD_NUMBER` before archive |

`ci_pre_xcodebuild.sh` mirrors GitHub Actions (`agvtool new-version -all
$GITHUB_RUN_NUMBER`) so build numbers stay monotonic across both CI systems.

## Install on device

After a successful workflow:

1. Wait for Apple to finish processing the build in App Store Connect.
2. Open the **TestFlight** app on your iPhone.
3. Install **Ebbie** (App Store Connect name; on-device name may differ).

## Usage and cost

- Included: **25 compute hours/month** with your Developer Program membership.
- Monitor usage: **App Store Connect → Users and Access → Xcode Cloud**, or the
  Apple Developer app → **Account → Xcode Cloud**.
- Parallel test runs consume hours faster than a single archive action.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Workflow not offered in Xcode | Ensure you have Admin/App Manager role and the repo is connected under **App Store Connect → Xcode Cloud** |
| Signing errors | Confirm team `3F274MB2RL` in workflow Environment; verify bundle ID `com.bcbs.ebb` is registered |
| Build not in TestFlight | Check archive action succeeded; processing can take 10–30 min |
| Testers don't see build | Confirm **Ebb Internal** group exists and has **access to all builds**; tester must be an ASC team member |
| `ci_scripts` not running | Scripts must live in `Ebb/ci_scripts/` (next to `Ebb.xcodeproj`) and be executable (`chmod +x`) |
| Duplicate build number | `ci_pre_xcodebuild.sh` should run on archive; check logs for `Setting build number to CI_BUILD_NUMBER=` |

## GitHub Actions vs Xcode Cloud

| | GitHub Actions | Xcode Cloud |
|---|----------------|-------------|
| Config | `.github/workflows/testflight.yml` | Xcode / App Store Connect UI |
| Trigger | Push to `app/ebb`, manual dispatch | Push to `app/ebb`, manual start |
| Screenshots | Yes | No (keep GitHub Actions for screenshots) |
| Signing | API key + `-allowProvisioningUpdates` | Managed by Apple |
| Beta group setup | `ci/create_beta_group.rb` | Use existing **Ebb Internal** group in post-action |

You can run both: GitHub Actions for PR tests and screenshots, Xcode Cloud for
native archive → TestFlight on `app/ebb` pushes.
