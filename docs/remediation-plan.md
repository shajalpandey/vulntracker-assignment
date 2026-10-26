# Remediation Plan

Numbers match `findings.md`.

## What I fixed

| # | Problem | What I did | How I checked |
|---|---|---|---|
| 1 | SQL injection in search | Search no longer puts user text into the SQL. | Checked the new query: user text is passed as a parameter, not inside the SQL as formatted string. Tests pass. |
| 2 | Users could read each other's scans | The scan lookup now also checks who owns it | A second user asked for scan 1 and got 404 |
| 3 | Unsigned tokens accepted | Only the HS256 signing method is allowed now | Tests pass |
| 4 | Secrets in the code | The key now comes from `.env`. The app won't start without it; removed the unused admin key and database password | App starts with a key and stops without one |
| 5 | Passwords in the logs | Removed them from the login logs | Logged in and checked the output: no password |
| 6 | Old Python libraries | Upgraded them | Scan again: 19 findings became 0 |
| 7 | Extra tools in the image | Removed `setuptools` and `wheel` | Rebuilt and scanned the image again |
| 8 Chart: no group ID | Set `runAsGroup` in the Deployment | Scanned the chart again: finding gone |

## What is still open

1. **Replace the old secrets (4).** The login key, admin key, database password and Node service key are all in the git history, so they count as leaked and must never be used again. The new login key is random and only lives in `.env`. In a real deployment it should come from a secrets manager. The Node service key is still hard-coded in `notify/src/config.js` and should be read from the environment.
2. **Debian packages (7).** There are no fixes yet. I will scan every week and rebuild when fixes come out.
3. **CI action versions (9).** Pin each action to a full commit SHA instead of `@v4` or `@v5`.
4. **Registry warning on the chart (11).** Trivy flags our own Artifact Registry as untrusted. We accepted this, since it is our private registry.

## What I would add next or what i've done

- Run the scans in CI so new problems fail the build.
- Add a secret scanner, because none of my scanners found the hard-coded secrets.(added gitleaks scan created the report)
- The shared link can be guessed with wrong passwords. Some limit needs to be there.