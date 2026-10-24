# VulnTracker

VulnTracker keeps track of vulnerability scan results. It has two services:

- **`app/`** is the main API, written in Python (FastAPI). Users register, log in, and add, search, update and delete their scans. A scan owner can also share one scan with someone who has no account.
- **`notify/`** is a notification service, written in Node.js (Express). The API calls it when a scan is created or updated.

This repo also has the security work I did on top of the starter code: scans, fixes, a Docker image and a Helm chart. See [Security work](#security-work).

## Run it on your computer

You need Python 3.11, Node.js 20 or newer, and Docker (only for the Docker option).

**1. Set the secret key.** The API will not start without one.

```bash
cp .env.example .env
```

`.env` is not committed to git, so your real key stays private. `.env.example` is committed and only shows what the file should look like. Open `.env` and replace `change-me` with a random key of at least 32 characters. You can make one with:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

**2. Start the API.**

```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd app
python -m uvicorn main:app --reload
```

The API runs at http://localhost:8000. You can try every endpoint at http://localhost:8000/docs.

**3. Start the notification service** (optional, in a second terminal).

```bash
cd notify
npm install
npm start
```

It runs at http://localhost:3001.

**4. Run the tests.**

```bash
python -m pytest tests/ -v     # Python tests, from the repo root
cd notify && npm test          # Node tests
```

The Python tests set a dummy key themselves, so they pass without a `.env` file (this is also how they pass in CI).

## Run it with Docker

Build the image from the repo root:

```bash
docker build -t vulntracker:1.0.0 .
```

Run it:

```bash
docker run -d --name vulntracker -p 8000:8000 --env-file .env vulntracker:1.0.0
```

Then open http://localhost:8000/docs. `docker ps` should show the container as `healthy`. To stop it: `docker rm -f vulntracker`.

The container cannot see your `.env` file, because the file is kept out of the image on purpose. `--env-file .env` hands its values to the container as environment variables, and the code reads the key from there.

About the image:
- It is based on a slim Python image, pinned to a fixed digest.
- It runs as a non-root user.
- It has a `HEALTHCHECK`.
- It has no secrets inside.
- The code is read-only. Only the `/data` folder is writable, because that is where the database file lives.

## Shared report links

The owner of a scan can create a link that shows that one scan to someone who has no account, such as a customer or an auditor.

- Anyone with the link can see that one scan and nothing else.
- The link stops working after **24 hours**.
- The owner can add an optional **password** to the link.

| Who | Endpoint | What it does |
|---|---|---|
| The owner (logged in) | `POST /scans/{scan_id}/share` | Creates a link for one of their scans |
| Anyone with the link | `GET /share/{token}` | Shows the scan (no login needed). If the link has a password, add `?password=...` |

**How it is kept safe**
- Only the owner can share a scan. Asking to share someone else's scan gives a 404.
- The link cannot be guessed. The token is random and about 43 characters long.
- Secrets are not stored as they are. The database keeps a hash of the token and a bcrypt hash of the password, never the real values.
- The person with the link sees only safe fields. `owner_id` and `remediation_notes` are never sent.

**Choices I made**
- **`share_url` is fixed to `http://localhost:8000`.** I kept it simple for this assignment. In a real deployment the base URL should come from a setting, so the link points at the real address.
- The scan ID is in the URL, as the task asks. The request body holds only the optional password.

**Known limits**
- The password goes in the URL (`?password=...`). URLs can end up in logs.
- There is no limit on wrong password guesses, so someone could keep guessing.
- A link cannot be cancelled before it expires.

**What I tested by hand**

| Test | Result |
|---|---|
| Another user tries to share my scan | 404 |
| Opening a protected link with the wrong password | 401 |
| Opening a link that has expired | 403 |

## Security work

| What | Where |
|---|---|
| Scan results (raw JSON) | `reports/` — code (Semgrep), dependencies (Trivy), container image (Trivy), Helm chart (Trivy) and secrets (gitleaks) |
| Scans after the fixes | `reports/after/` |
| Findings, ranked | `docs/findings.md` |
| What I fixed and what is still open | `docs/remediation-plan.md` |
| Summary for a CISO | `docs/executive-summary.md` |

Fixes made in the code: SQL injection in search, users reading each other's scans, unsigned login tokens, hard-coded secrets, and passwords written to the logs. I also upgraded the vulnerable Python libraries.

## Deploying to Kubernetes

The Helm chart is in `helm/vulntracker/`. It contains:

- **Secrets from a secrets manager.** An `ExternalSecret` fetches `SECRET_KEY` from Google Secret Manager and creates a Kubernetes Secret. No secret value is written in the chart.
- **Limited network access.** A `NetworkPolicy` lets only the ingress controller reach the pods, and only on port 8000. The Service is `ClusterIP`, so it is not exposed outside the cluster.
- **Resource limits** for CPU and memory.
- **Security contexts.** The pod runs as a non-root user, cannot gain extra privileges, drops all Linux capabilities and has a read-only filesystem.
- **Health probes** that call `/health`.

Before you deploy:
1. Install [External Secrets Operator](https://external-secrets.io) in the cluster.
2. Create the secret in Google Secret Manager:
   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(32), end='')" | \
     gcloud secrets create vulntracker-secret-key --replication-policy=automatic --data-file=-
   ```
3. Give the service account in `values.yaml` (`external-secrets-sa`) access to read that secret.
4. Replace the placeholders in `helm/vulntracker/values.yaml`: the project ID, cluster name and location, and the image path.

Then check and install:

```bash
helm lint helm/vulntracker
helm template vulntracker helm/vulntracker
helm install vulntracker helm/vulntracker --namespace vulntracker --create-namespace
```

## Folders

```
app/        Python API
notify/     Node.js notification service
tests/      Python tests
helm/       Helm chart
reports/    Scan results (JSON)
docs/       Findings, remediation plan, executive summary
Dockerfile  Image for the Python API
```

# Security Automation Engineer — Take-Home Assignment

Welcome. This assignment is designed to reflect the real work of a Lead Security Automation Engineer: extending an existing service, identifying and assessing security risks, remediating them with code, and deploying it securely. There are no trick questions — we are evaluating your depth of knowledge, your judgment under constraints, and your ability to communicate risk.

**Estimated time: 4–6 hours.** We respect your time. If you find yourself going significantly over, scope down rather than rushing.

---

## Background

**VulnTracker** is a two-service system for managing vulnerability scan results:

- **`app/`** — Python/FastAPI REST API. Security teams use it to log findings, track remediation, and share reports with stakeholders.
- **`notify/`** — Node.js/Express notification service. Intended to dispatch webhook events to registered endpoints when scan records are created or updated.

Both services are working but imperfect internal prototypes. Neither has gone through a formal security review. The Python API calls the notification service in the background whenever a scan is created or updated — start both services to see the full flow.

---

## Getting Started

**Create your own repository for this assignment.** Do not fork — your solution must be in a fresh repo. You may use the starter code as a base, but your work must be in your own repo.

```bash
# 1. Clone the assignment repo locally
git clone https://github.com/cloudtriquetra/asa-assignment.git
cd asa-assignment

# 2. Point it at your own new GitHub repo (create one first at github.com)
git remote set-url origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

From here, work on your own repo and share its URL when you submit.

**Requirements:** Python 3.11 (exactly — see CI), Node.js 20+, Docker

**Python API (`app/`)**

```bash
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

The API must be started from inside the `app/` directory — the modules use bare imports and won't resolve from the repo root:

```bash
cd app
uvicorn main:app --reload
```

Available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

Run the Python test suite from the **repo root**:

```bash
pytest tests/ -v
```

**Notification Service (`notify/`)**

```bash
cd notify
npm install
npm start
```

Available at `http://localhost:3001`.

Run the Node.js test suite (stop the notify service first if it is running — the test suite starts its own server on the same port):

```bash
cd notify
npm test
```

---

## Your Tasks

### Task 1 — Extend the App _(~1–1.5 hrs)_

Implement the **"Shared Report Link"** feature:

> As a VulnTracker user, I want to share a specific scan result with an external stakeholder (e.g. a customer or auditor) via a unique link. The link must expire after **24 hours** and must support **optional password protection**.

Add the following endpoints to the app:

| Method | Path                     | Auth          | Description                                                                                                              |
| ------ | ------------------------ | ------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `POST` | `/scans/{scan_id}/share` | Bearer token  | Generate a share token for a scan. Accepts optional `password` in the request body. Returns `{ "share_url": "..." }`     |
| `GET`  | `/share/{token}`         | None (public) | Return the scan data if the token is valid and not expired. If password-protected, require a `password` query parameter. |

Implementation choices are yours. We will read and evaluate the code you write here — including the security properties of your implementation. For the `share_url` value, use the incoming request's host, or hard-code `http://localhost:8000` for the prototype — document whichever you choose.

---

### Task 2 — Security Analysis _(~1.5 hrs)_

#### 2a. Run the required scans

You must run **all four** of the following scan categories. Select an appropriate open-source or free-tier tool for each — your tool choices are part of the evaluation.

| Scan type                                      | What it covers                                                                         |
| ---------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Static Application Security Testing (SAST)** | Source code — identify insecure coding patterns, injection risks, hardcoded secrets    |
| **Dependency / SCA vulnerability scan**        | Third-party packages — known CVEs in pinned dependencies                               |
| **Container image scan**                       | The Docker image you build — OS packages, installed libraries, misconfigurations       |
| **Infrastructure-as-Code (IaC) security scan** | Your Helm chart or Terraform — misconfigurations, insecure defaults, policy violations. Complete Task 4 first, then run this scan. |

Save the raw JSON output of each tool to the `reports/` directory, named clearly by scan type:

```
reports/
├── sast.<tool>.json
├── sca.<tool>.json
├── container.<tool>.json
└── iac.<tool>.json
```

#### 2b. Prioritised findings

Write a `docs/findings.md` with a table of security findings, sourced from your scans and your own manual review. For each finding:

- Tool and scan type that detected it (or "manual")
- Severity (your assessment — justify it)
- Business impact in the context of _this specific application_
- Whether it is in the starter code or in your new feature

**Do not copy-paste tool output.** We are evaluating your ability to interpret findings and apply business context to prioritisation — not your ability to run a command.

---

### Task 3 — Remediate _(~1 hr)_

- Fix **at least 3 critical or high severity findings** in code. Show the changes clearly (they will be visible in your git diff / PR).
- At least one fix must be in the code you wrote in Task 1.
- For findings you do not fix, document why in `docs/remediation-plan.md`: what is the residual risk, what effort would remediation require, and what compensating controls (if any) exist?

---

### Task 4 — Containerisation and Deployment Artifacts _(~30–45 min)_

#### Dockerfile (mandatory)

Write a production-grade `Dockerfile` for the **Python FastAPI service** (`app/`). It must:

- Use a minimal, pinned base image
- Run as a non-root user
- Include a `HEALTHCHECK`
- Not embed secrets or credentials

The container image must build successfully and the app must be reachable via `docker run`. Include build and run instructions in your README.

#### Infrastructure

Add either a `terraform/` or `helm/` directory (your choice) that could deploy this service to a Kubernetes cluster or cloud environment. Your deployment must:

- Source secrets from a secrets manager (not hardcoded in manifests or env vars)
- Restrict network ingress to only what is required
- Define resource limits and security contexts

---

### Task 5 — Executive Summary _(~30 min)_

Write `docs/executive-summary.md` as if you are presenting to a CISO who has 5 minutes.

Cover:

1. The overall security posture of the application before and after your work
2. The top 3 residual risks and the reason they were not fully remediated
3. Your recommended next steps if this were a real production service

No jargon. No tool names in the first paragraph. Your audience cares about business risk, not CVE numbers.

---

## Submission

Push your completed solution to your own GitHub repository and share the URL with us. Your repository must contain:

```
/
├── app/                        # extended Python API code
├── notify/                     # Node.js notification service (no changes required)
├── Dockerfile                  # mandatory (may cover one or both services)
├── reports/
│   ├── sast.<tool>.json
│   ├── sca.<tool>.json
│   ├── container.<tool>.json
│   └── iac.<tool>.json
├── terraform/  OR  helm/
├── docs/
│   ├── findings.md
│   ├── remediation-plan.md
│   └── executive-summary.md
├── tests/                      # updated if you added Python tests
└── README.md                   # update with Docker build/run instructions
```

CI must pass (green) on your repo before submission.

---

## What We Are Looking For

We are not grading on volume. We are grading on judgment.

- **Security depth**: Did you find the real issues? Did you prioritise them correctly for this application?
- **Implementation security**: Does your new feature introduce, or avoid, new vulnerabilities?
- **Remediation quality**: Are your fixes correct and complete? Are your deferral reasons honest?
- **Deployment security**: Does your container and infrastructure configuration reflect real-world security practices?
- **Communication**: Would a non-technical executive understand your summary?

Good luck. If anything in the brief is ambiguous, document your assumption and proceed.
