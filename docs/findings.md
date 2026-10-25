# Findings

I read the code by hand and ran four scans: Semgrep (code), Trivy (dependencies and container image) and an infrastructure scan. Severity is my own rating.

| # | Issue | Severity | Status |
|---|---|---|---|
| 1 | SQL injection in scan search | Critical | Fixed |
| 2 | Any user can read another user's scan | High | Fixed |
| 3 | JWT accepts unsigned tokens | High | Fixed |
| 4 | Secrets hard-coded in the source | High | Fixed (key must be rotated) |
| 5 | Passwords written to the logs | High | Fixed |
| 6 | Vulnerable Python libraries | Critical / High | Fixed |
| 7 | Unfixed OS package vulnerabilities in the image | High | Open |
| 8 | Build tools left in the container image | Low | Fixed |
| 9 | CI actions use version tags, not fixed commits | Low | Open |

## 1. SQL injection in scan search
- **Where:** `app/database.py`, `search_scans_by_query`
- **Problem:** text() does not protect you from SQL injection if you combine it with Python format strings (f-strings).
- **Impact:** Malicious text or string can be added in the query which can exploit the database.
- **Fix:** The text() is combined with SQLAlchemy placeholders thus only data values can be inserted.

## 2. Any user can read another user's scan
- **Where:** `app/main.py`, `get_scan`
- **Problem:** The scan was looked up by ID only. The owner was never checked.
- **Impact:** I logged in as a second user and opened scan 1, which belongs to someone else. It worked.
- **Fix:** The lookup now also filters on the current user's ID. Other people's scans return 404.

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

## What the scanners missed
- Semgrep and Trivy (file and image scans) did not find the hard-coded secrets in finding 4. I only found them by reading the code.
- Semgrep may consider them as legitimate keys. Howver this can be resolved by creating a custom rule that includes pattern addition for these keys detection
- I've used Gitleaks scanning to detect sensitive keys and report is present under reports/ folder.