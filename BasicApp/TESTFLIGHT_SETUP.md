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

Add these under **Settings → Secrets and variables → Actions**.

### Pasting the `.p8` key correctly

The private key must be multiple lines. In GitHub Secrets, paste the entire file:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49Aw...
-----END PRIVATE KEY-----
```

Do not wrap it in extra quotes.

## Deploy

1. Go to **Actions → TestFlight → Run workflow**
2. Wait for the build to finish (~10–15 min)
3. Open **TestFlight** on your iPhone and install **BasicApp**

First upload may take an extra 10–30 minutes for Apple to process.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `invalid curve name` | Re-paste the `.p8` secret with correct newlines |
| `missing BEGIN PRIVATE KEY` | The secret is empty or truncated |
| `Authentication failed` | Check Issuer ID and Key ID variables |
