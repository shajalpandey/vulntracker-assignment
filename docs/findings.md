# Findings

I read the code by hand and ran four scans: Semgrep (code), Trivy (dependencies and container image) and an infrastructure scan. Severity is my own rating.

| # | Issue | Severity | Status |
|---|---|---|---|
| 1 | SQL injection in scan search | Critical | Fixed |
| 2 | Any user can read another user's scan | High | Fixed |
| 3 | JWT accepts unsigned tokens | High | Fixed |
| 4 | Secrets hard-coded in the source | High | Partly Fixed (key must be rotated) |
| 5 | Passwords written to the logs | High | Fixed |
| 6 | Vulnerable Python libraries | Critical / High | Fixed |
| 7 | Unfixed OS package vulnerabilities in the image | High | Open |
| 8 | Build tools left in the container image | Low | Fixed |
| 9 | CI actions use version tags, not fixed commits | Low | Open |
| 10 | Helm chart: container group ID not set | Low | Fixed |
| 11 | Helm chart: image comes from a registry the scanner does not trust | Medium | Accepted |

## 1. SQL injection in scan search
- **Where:** `app/database.py`, `search_scans_by_query`
- **Problem:** text() does not protect you from SQL injection if you combine it with Python format strings (f-strings).
- **Impact:** Malicious text or string can be added in the query which can exploit the database.
- **Fix:** The text() is combined with SQLAlchemy placeholders thus only data values can be inserted.

## 4. Secrets hard-coded in the source
- **Where:** `app/config.py` and `notify/src/config.js`
- **Problem:** Four secrets were written in the code: the login signing key, an admin API key, a database password and the notification service key.
- **Impact:** Anyone with the repo can sign valid login tokens. The values are also in the git history.
- **How I found it:** Reading the code, and the secrets scan (gitleaks). The standard rules found two of the four. A custom rule I added found all four. Semgrep and Trivy found none.
- **Fix:** In `app/config.py`, `SECRET_KEY` now comes from the environment (`.env`, which git ignores), and the app will not start without it. I removed the admin key and the database password because nothing used them.
- **Not fixed:** `notify/src/config.js` still has a hard-coded `SERVICE_KEY`. It should be read from the environment too.
- **Still to do:** All four secrets are in the git history, so they count as leaked and must never be used again.

## 3. JWT accepts unsigned tokens
- **Where:** `app/auth.py`
- **Problem:** The token check allowed the algorithm `none`, which means no signature.
- **Impact:** Anyone could make a token for any user and the app would trust it.
- **Fix:** Only HS256 is allowed now. I also moved to the maintained PyJWT library.

## 4. Secrets hard-coded in the source
- **Where:** `app/config.py`
- **Problem:** The JWT signing key, a database password and an admin API key were written in the file.
- **Impact:** Anyone with the repo can sign valid tokens. The values are also in the git history.
- **Fix:** `SECRET_KEY` now comes from the environment (`.env`, which git ignores), and the app will not start without it. I removed the other two values because nothing used them.

## 5. Passwords written to the logs
- **Where:** `app/main.py`, login route
- **Problem:** Every login attempt logged the username and the plain password, including failed ones.
- **Impact:** Anyone who can read the logs can read passwords.
- **Fix:** I removed the password from both log lines.

## 6. Vulnerable Python libraries
- **Where:** `requirements.txt`
- **Problem:** Trivy found 19 known vulnerabilities, 3 of them critical.
- **Fix:** I upgraded the libraries. A new scan shows 0 findings in the Python part of the image.

## 7. Unfixed OS package vulnerabilities in the image
- **Where:** Debian packages in the base image
- **Problem:** Trivy reports 44 high-severity issues in the OS packages.
- **Why it is open:** Debian has not released fixes yet, so I cannot fix them.
- **What I did instead:** The image is slim, runs as a non-root user and has nothing extra installed. I would rescan regularly and rebuild when fixes come out.

## 8. Build tools left in the container image
- **Where:** `Dockerfile`
- **Problem:** `setuptools` and `wheel` came with the base image and are not needed to run the app.
- **Fix:** The Dockerfile removes them, so there is less in the image to attack.

## 9. CI actions use version tags, not fixed commits
- **Where:** `.github/workflows/ci.yml`
- **Problem:** Actions are referenced as `@v4` and `@v5`. A tag can be moved, so the code behind it can change.
- **Status:** Open. I would pin each action to a full commit SHA.

## 10. Helm chart: container group ID not set
- **Where:** `helm/vulntracker/templates/deployment.yaml`
- **Problem:** The chart set the user ID but not the group ID, so the process could run with a group that clashes with one on the host.
- **Found by:** The chart scan (Trivy).
- **Fix:** I set `runAsGroup` to 10001. A second scan no longer shows it. This has been incorporated in security context.

## 11. Helm chart: image comes from a registry the scanner does not trust
- **Where:** `helm/vulntracker/templates/deployment.yaml`
- **Problem:** The scanner has a short built-in list of trusted registries, and our Google Artifact Registry is not on it.
- **Found by:** The chart scan (Trivy).
- **Status:** Accepted. It is our own private registry, so the image source is trusted. Changing the scanner's list needs a custom rule, which is not worth it here.

## What the scanners missed
- - Semgrep and Trivy did not find any of the hard-coded secrets. The standard gitleaks rules found two of the four. A custom gitleaks rule found all four.
- Semgrep may consider them as legitimate keys. Howver this can be resolved by creating a custom rule that includes pattern addition for these keys detection
- I've used Gitleaks scanning to detect sensitive keys and report is present under reports/ folder.

## Notes on the scan results
- The secrets scan also read my own report files in `reports/`. It flagged the earlier gitleaks report, which repeats the keys it had found, and a `GPG_KEY` value in the container scan reports. These are not new problems and can be ignored. The GPG value is the public ID of the key that signs Python releases, not a secret.
- The gitleaks report shows the old key values on purpose, so the matches can be checked. All of them are already in the git history and must be treated as leaked.