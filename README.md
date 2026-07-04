# Secure Cloud Deployment Pipeline

A portfolio project combining cloud engineering, QA automation, and security testing —
built to demonstrate practical, hands-on application of ISTQB, AWS Cloud Practitioner,
and Azure AZ-900 certifications, plus foundational cybersecurity skills.

## Project Goal

Deploy a small serverless to-do API on AWS using Infrastructure as Code, then build an
automated pipeline that tests it (QA) and scans it for vulnerabilities (security) on
every code change — all within AWS Free Tier (€0 cost).

## Architecture

- **App**: Serverless to-do list API (create / list / delete items)
- **Compute**: AWS Lambda + API Gateway
- **Database**: DynamoDB (free tier: 25GB always free)
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Testing**: Pytest (API tests, ISTQB-style test design)
- **Security**: OWASP ZAP baseline scan

## Why This Project

| Skill area | Certification | What this project demonstrates |
|---|---|---|
| QA / Testing | ISTQB | Test case design (equivalence partitioning, boundary value analysis), automated API testing |
| Cloud Engineering | AWS Cloud Practitioner, Azure AZ-900 | Infrastructure as Code, serverless architecture, multi-cloud awareness |
| Cybersecurity | (in progress) | Vulnerability scanning, security reporting |

## Progress Log

This README is updated step by step as the project is built — each entry reflects real
work done, in order, so it can also serve as a build diary.

### Step 0 — Project scaffolding (✅ done)
- Created project structure: `app/`, `terraform/`, `tests/`, `.github/workflows/`
- Defined architecture and goals

### Step 1 — Local tooling + AWS account setup (✅ done)
- Installed Homebrew, AWS CLI, and Terraform on macOS
- Created AWS account, resolved card verification with bank
- Set a $1 AWS Budget alert to catch any unexpected spend early
- Created a dedicated IAM user (`terraform-deploy`) with an Access Key — avoids using root
  account credentials for daily work, a security best practice worth mentioning in interviews
- GitHub authentication set up via Personal Access Token (PAT) + macOS Keychain

### Step 2 — First Terraform resource: DynamoDB table (✅ done)
- Added `terraform/provider.tf` — AWS provider configuration (region: `eu-west-1`, closest to Spain)
- Added `terraform/variables.tf` — reusable project name, environment, and region variables
- Added `terraform/dynamodb.tf` — the `todos` table using **on-demand billing** (PAY_PER_REQUEST),
  which stays within AWS Free Tier for low-traffic use and avoids paying for idle provisioned capacity
- Added `terraform/outputs.tf` — exposes the table name/ARN after deploy, so later steps (Lambda) can reference it
- **Design decision documented**: chose on-demand billing mode specifically to guarantee €0 cost
  for a portfolio project with sporadic traffic, rather than provisioned throughput

**Next**: run `terraform init` and `terraform plan` once the AWS account/IAM user is ready, to validate
the table definition before writing the Lambda function that will read/write to it.

### Step 3 — First real deploy: `terraform apply` (✅ done)
- Ran `aws configure` locally with the `terraform-deploy` IAM user's access key
- Verified credentials with `aws sts get-caller-identity`
- Ran `terraform init` → downloaded the AWS provider plugin successfully
- Ran `terraform plan` → confirmed only the intended resource (`aws_dynamodb_table.todos`)
  would be created, nothing unexpected
- Ran `terraform apply` and confirmed with `yes` → **DynamoDB table successfully created in AWS**
  - Table name: `secure-cloud-pipeline-todos-dev`
  - Region: `eu-west-1`
  - Billing mode: on-demand (PAY_PER_REQUEST)

This is the first real piece of infrastructure provisioned entirely through code rather than
clicking through the AWS Console — the core principle of Infrastructure as Code (IaC).

**Next**: write the Lambda function (Python) that will read/write items to this table, then the
API Gateway that exposes it over HTTP.

---

### Step 4 — Lambda functions: application logic (✅ done)
Chose a **separate Lambda per operation** design (rather than one monolithic handler) — this
mirrors a real microservices pattern, where each function has a single responsibility and its
own IAM permissions, and is easier to test and secure independently.

- **`app/create_todo.py`** — `POST /todos`. Validates input (required field, empty-string check,
  200-character length boundary), generates a UUID, writes the item to DynamoDB.
  Input validation explicitly applies **ISTQB test design techniques**: equivalence
  partitioning (empty / missing / valid / too-long title) and boundary value analysis
  (the 200-character limit).
- **`app/list_todos.py`** — `GET /todos`. Scans the DynamoDB table and returns all items.
  Documented a known trade-off: `scan()` reads the whole table, which is fine at this
  project's scale but wouldn't be the right choice at production scale (a `Query` with an
  index would be preferred there).
- **`app/delete_todo.py`** — `DELETE /todos/{id}`. Checks the item exists first (to return a
  proper `404` instead of a silent no-op — DynamoDB's default delete behavior doesn't error
  on a missing key), then deletes it.

All three functions read the DynamoDB table name from an environment variable (`TABLE_NAME`)
rather than hardcoding it — this keeps the code portable between environments (dev/prod) and
is set via Terraform in the next step.

**Next**: write Terraform for the Lambda functions, their IAM execution role, and the API Gateway
that exposes them over HTTP — then do the first end-to-end deploy and test with `curl`.

---

### Step 5 — Terraform: Lambda, IAM, and API Gateway (✅ done)

- **`terraform/iam.tf`** — a dedicated IAM role for the Lambdas with a **custom least-privilege
  policy**: only `PutItem`, `Scan`, `GetItem`, `DeleteItem`, scoped to this one DynamoDB table's
  ARN specifically (not `dynamodb:*` on `*`). This is a deliberate security decision worth
  explaining in interviews — it limits blast radius if credentials were ever compromised.
- **`terraform/lambda.tf`** — defines the three Lambda functions, using `archive_file` to
  auto-zip each `.py` file from `app/` at plan/apply time (no manual zipping step). Table name
  is injected via environment variable, keeping code environment-agnostic.
- **`terraform/api_gateway.tf`** — an **HTTP API** (chosen over REST API for lower cost and
  simpler configuration, appropriate for this project's scale) with three routes:
  - `POST /todos` → create_todo
  - `GET /todos` → list_todos
  - `DELETE /todos/{id}` → delete_todo

  Each route has its own `aws_lambda_permission`, explicitly authorizing only API Gateway to
  invoke that specific function — another least-privilege decision.
- Added `api_endpoint` output so the live API URL is printed after `terraform apply`.

**Next**: run `terraform plan` / `terraform apply` for this new infrastructure, then test all
three endpoints live with `curl`.

---

### Step 6 — First end-to-end deploy and live test (✅ done)

- Ran `terraform plan` → **17 resources to add** (IAM role + policy + attachment, 3 Lambdas,
  API Gateway + stage, 3 integrations, 3 routes, 3 permissions), 0 unexpected changes
- Ran `terraform apply` → all 17 resources created successfully
- **Live API endpoint**: `https://rf90i1a453.execute-api.eu-west-1.amazonaws.com`

Tested the full pipeline end-to-end with `curl`:

| Test | Result |
|---|---|
| `POST /todos` with valid title | ✅ 201, returned item with generated UUID |
| `GET /todos` | ✅ 200, returned array containing the created item |
| `DELETE /todos/{id}` | ✅ 200, confirmed deletion |
| `GET /todos` after delete | ✅ 200, empty array — confirms delete actually persisted |
| `POST /todos` with empty title | ✅ 400, correctly rejected by input validation |

This confirms the full chain works end-to-end: **Terraform → IAM → Lambda → DynamoDB → API
Gateway**, all provisioned as code and verified live. This is the core "Secure Cloud Deployment
Pipeline" milestone — a working serverless API deployed entirely through Infrastructure as Code.

**Next**: move to automated testing — replace manual `curl` checks with a proper Pytest suite
(applying ISTQB test design techniques formally: equivalence partitioning, boundary value
analysis, and a documented test plan), then wire it into GitHub Actions CI/CD.

---

### Step 7 — Automated testing with Pytest (✅ done)

Replaced manual `curl` checks with a proper, repeatable Pytest suite. The API URL is read from
an **environment variable** (`API_URL`) rather than hardcoded, so the same test suite can run
against any deployment (local, CI/CD, future prod) without code changes.

- **`tests/conftest.py`** — shared fixtures: the `api_url` fixture reads `API_URL` from the
  environment and fails with a clear message if it's not set; helper functions for creating
  and deleting to-do items, reused across test files to avoid duplication.
- **`tests/test_create_todo.py`** — tests `POST /todos`, explicitly applying two ISTQB test
  design techniques:
  - **Equivalence Partitioning**: one representative test per input class — valid title,
    empty string, missing field, whitespace-only string — rather than many redundant
    valid-input tests.
  - **Boundary Value Analysis**: tests exactly at the 200-character limit (should pass),
    one over it at 201 (should fail), and one under at 199 (should pass) — boundaries are
    where off-by-one bugs typically hide.
- **`tests/test_list_and_delete_todo.py`** — tests `GET /todos` and `DELETE /todos/{id}`,
  including equivalence partitioning for delete (existing id vs. non-existent id → 404,
  not a silent no-op) and a state-based check confirming a deleted item actually disappears
  from the list.
- **`tests/requirements.txt`** — pinned `pytest` and `requests` versions for reproducibility.

Every test that creates a to-do item cleans up after itself (deletes it), so repeated test
runs don't pollute the DynamoDB table with leftover data.

**Next**: run the suite locally against the live API to confirm it all passes, then wire it
into a GitHub Actions workflow so tests run automatically on every push.

---

### Step 8 — Version control: git + GitHub (✅ done)

- Created `.gitignore` to exclude local/generated files from version control:
  Terraform cache (`.terraform/`), state files (`*.tfstate*`, since these can contain
  sensitive resource details — a shared remote backend like S3 would be the production-grade
  alternative), auto-generated Lambda zips (`terraform/build/`), and the Python `venv/`.
  **Note**: `.terraform.lock.hcl` is intentionally *not* ignored — Terraform itself recommends
  committing it, since it locks provider versions for reproducible builds.
- Initialized git, made the first commit (17 tracked files: README, `.gitignore`, 3 Lambda
  functions, 7 Terraform files, 4 test files)
- Created a **public** GitHub repository so the project is visible to employers:
  **[github.com/d-gam/secure-cloud-deployment-pipeline](https://github.com/d-gam/secure-cloud-deployment-pipeline)**
- Authenticated using a GitHub Personal Access Token (PAT) rather than a password, per GitHub's
  current security requirements
- Pushed the initial commit to the `main` branch

**Next**: run the Pytest suite locally to confirm everything passes, then write a GitHub Actions
workflow so tests (and later, the security scan) run automatically on every push — no more
manual `pytest` runs needed.

---

### Step 9 — First local Pytest run against the live API (✅ done)

Ran the full suite locally against the live deployed API:

```
12 passed in 6.44s
```

All test classes passed cleanly:
- `TestCreateTodoEquivalencePartitioning` (4 tests) — valid title, empty title, missing field,
  whitespace-only title
- `TestCreateTodoBoundaryValueAnalysis` (3 tests) — 199, 200, and 201 character boundaries
- `TestListTodos` (2 tests) — list returns created item, list returns a JSON array
- `TestDeleteTodo` (3 tests) — delete succeeds, deleted item disappears from list, deleting a
  non-existent id returns 404 rather than silently succeeding

This confirms the API behaves correctly under both valid and invalid input, and that the test
suite itself is reliable before wiring it into CI/CD — a good practice, since automating a
broken or flaky test suite just automates confusion.

**Next**: write a GitHub Actions workflow (`.github/workflows/`) so this suite runs automatically
on every push to `main`, without any manual `pytest` command needed.

---

### Step 10 — CI/CD: GitHub Actions workflow (✅ done)

Added `.github/workflows/test.yml` — a workflow that automatically runs the full Pytest suite on:
- Every push to `main`
- Every pull request targeting `main` (catches issues before merge, not just after)

**Scope decision**: kept this workflow to tests-only for now, running against the already-deployed
API, rather than also running `terraform apply` on every push. Combining automated infrastructure
changes with automated testing is a reasonable next step, but starting with test automation alone
is simpler to reason about and safer while still learning the CI/CD pattern.

The workflow:
1. Checks out the repo code
2. Sets up Python 3.12
3. Installs test dependencies from `tests/requirements.txt`
4. Runs `pytest tests/ -v` against the live API

The API URL is set directly as an environment variable in the workflow file rather than a GitHub
Secret, since it's a public endpoint rather than sensitive data — documented this distinction in
the workflow file itself as a note for future secrets (e.g. if the project later needs AWS
credentials in CI, those would go in **Settings → Secrets and Variables → Actions**).

**Next**: push this workflow to GitHub and watch it run automatically in the **Actions** tab —
this closes the loop on the "Secure Cloud Deployment Pipeline": code change → automated test →
visible pass/fail result, all without manual intervention.

---

### Step 11 — First automated CI run: pipeline complete (✅ done)

Pushed the workflow to GitHub. Hit one real-world snag worth documenting: the initial push was
**rejected by GitHub** with `refusing to allow a Personal Access Token to create or update
workflow ... without 'workflow' scope` — GitHub requires a token to explicitly carry the
`workflow` scope to push files inside `.github/workflows/`, as a security measure since these
files can execute code. Regenerated the PAT with both `repo` and `workflow` scopes, cleared the
old cached credential from macOS Keychain, and pushed again successfully.

**Result**: the "Run API Tests" workflow ran automatically in GitHub Actions, triggered purely by
the `git push` — **passed in 22 seconds**, no manual `pytest` command involved.

### 🎯 Project milestone reached

The full pipeline is now live and closed end-to-end:

```
Code change → git push → GitHub Actions triggers automatically
    → Pytest suite runs against the live API → pass/fail visible in the Actions tab
```

Combined with everything built in Steps 0–10, this project now demonstrates, with a working
public repository as evidence:

- **Infrastructure as Code** (Terraform: DynamoDB, Lambda, API Gateway, IAM — all provisioned
  from code, not clicked through a console)
- **Cloud engineering** (serverless AWS architecture, least-privilege IAM, environment-agnostic
  Lambda code, €0 cost design)
- **QA / testing** (ISTQB techniques — equivalence partitioning, boundary value analysis —
  applied to a real automated test suite, not just theory)
- **CI/CD** (GitHub Actions running tests automatically on every push)
- **Real-world troubleshooting**, documented as it happened rather than hidden: card
  verification issues, credential/PAT scope problems, file management mishaps — all resolved
  and logged here as part of the build diary

**Repository**: [github.com/d-gam/secure-cloud-deployment-pipeline](https://github.com/d-gam/secure-cloud-deployment-pipeline)
**Live API**: `https://rf90i1a453.execute-api.eu-west-1.amazonaws.com`

### Possible next steps (not yet started)
- OWASP ZAP baseline security scan, wired into the same GitHub Actions workflow
- Scope down the IAM role further (currently one shared execution role for all 3 Lambdas —
  could split into 3 roles, each with only the single permission that specific function needs)
- Add a `terraform apply` stage to the CI/CD pipeline for full automated deployment
- Add a simple front-end (static HTML/JS) hosted on S3, so the API has a visual demo

---

### Step 12 — Security scanning: OWASP ZAP baseline scan (✅ done)

Added `.github/workflows/security-scan.yml` — runs the industry-standard **OWASP ZAP baseline
scan** against the live API on every push to `main`, plus a manual trigger option
(`workflow_dispatch`) from the Actions tab.

**Design decisions and honest limitations documented here:**
- Kept as a **separate workflow file** from `test.yml`, so a scan result doesn't get confused
  with a test result — they check different things and can fail independently.
- Used `-I` (informational mode: don't fail the build on findings) rather than treating this
  as a hard release gate. This is a deliberate choice for a learning/portfolio project — the
  goal here is to *see and understand* what ZAP reports, not to silently block pushes. In a
  real production pipeline, high-severity findings would typically block deployment instead.
- **Known limitation, worth understanding rather than hiding**: ZAP's baseline scan is
  originally designed to crawl and analyze **HTML web pages**. This project is a pure JSON API
  with no HTML front-end, so the scan has less surface to work with than it would on a
  traditional website — expect fewer findings than a full web app scan would produce. This
  doesn't make the scan pointless: it still checks for missing security headers, TLS/HTTPS
  configuration, and basic HTTP-level issues, and understanding *why* a tool behaves
  differently on different target types is itself a real security skill.
- The scan report (HTML) is uploaded as a downloadable **workflow artifact**, so results are
  reviewable after each run without digging through raw logs.

**Next**: review the first scan report once it runs, and if time allows, add a small S3-hosted
static front-end later — that would give ZAP's spider actual HTML pages to crawl, producing a
more representative security scan result to talk about in interviews.

---

### Step 13 — First ZAP scan results and remediation (✅ done)

First scan completed with a clean result: **0 High, 0 Medium, 3 Low, 2 Informational** findings.
No serious vulnerabilities — expected, given AWS API Gateway's solid defaults — but the 3 Low
findings were real and worth fixing rather than just documenting.

**Findings (all missing security response headers):**
1. `Cross-Origin-Resource-Policy` header missing
2. `Strict-Transport-Security` (HSTS) header not set
3. `X-Content-Type-Options` header missing

**Remediation**: added all three headers to the response of every Lambda function
(`create_todo.py`, `list_todos.py`, `delete_todo.py`).

**One deliberate deviation from ZAP's literal suggestion, worth explaining in interviews**: ZAP's
own documentation for `Cross-Origin-Resource-Policy` recommends `same-origin`. This project's API
Gateway CORS configuration (`api_gateway.tf`) intentionally sets `allow_origins = ["*"]`, because
the API is meant to be callable from any front-end origin (e.g. a future separate front-end app).
Setting `Cross-Origin-Resource-Policy: same-origin` would directly contradict that and break
legitimate cross-origin usage. Used `cross-origin` instead — the correct value for a resource
that's intentionally meant to be shared across origins. This is a good example of why security
tool output needs to be interpreted in the context of the actual system, not applied blindly.

**Also noted**: one of the two initial GitHub Actions runs for this workflow failed while the
other (same commit) passed — investigated as a transient CI issue rather than a real security
failure, since the report from the successful run showed a clean, complete scan.

This closes the loop on the security portion of the project: found → understood → fixed →
documented, with the reasoning behind the fix, not just the fix itself.

---

### Step 14 — Verifying the fix, and a deeper structural finding (✅ done)

Re-ran the ZAP scan after deploying the header fixes. Result: **Cross-Origin-Resource-Policy and
X-Content-Type-Options findings fully resolved.** The Strict-Transport-Security (HSTS) finding
dropped from 5 instances to 4, but didn't disappear entirely — worth investigating why rather
than assuming the fix was incomplete.

**Root cause**: the 4 remaining HSTS instances were all on paths never defined in the API
(`/`, `/favicon.ico`, `/robots.txt`, `/sitemap.xml`). These requests never reach Lambda code at
all — API Gateway returns its own built-in 404 for undefined routes before any application code
runs, so there's no way to attach a header to that response from inside a Lambda function. This
is a genuine structural limitation of a "bare" serverless API, not a bug in the fix.

**Decision**: rather than treating this as an acceptable gap, added a **CloudFront distribution**
in front of API Gateway — the standard, production-grade solution to this exact problem.

- **`terraform/cloudfront.tf`**:
  - An `aws_cloudfront_response_headers_policy` centralizing the security headers (HSTS,
    X-Content-Type-Options, Cross-Origin-Resource-Policy) so they're enforced **at the edge**,
    applied to every response that passes through CloudFront — including error responses that
    never reach the application, closing the exact gap found above.
  - An `aws_cloudfront_distribution` using API Gateway as a custom origin, HTTPS-only,
    `PriceClass_100` (cheapest tier, sufficient for a portfolio project, keeps cost at €0 within
    CloudFront's free tier).
  - Caching intentionally disabled (`min_ttl`/`default_ttl`/`max_ttl` = 0) — this is a dynamic
    API where `GET /todos` must always reflect current state, not a static site CloudFront would
    normally cache aggressively.
- Added `cloudfront_domain_name` output — this becomes the new public entry point to the API
  going forward, instead of the raw API Gateway URL.

**Broader takeaway worth mentioning in interviews**: CloudFront + API Gateway is a very common
production pattern (adds edge caching, custom domains, and WAF integration potential later) —
this wasn't just "fixing a scan finding," it's adopting a standard architecture specifically
because the simpler setup had a real, explainable limitation.

**Note**: CloudFront distributions take 10-20 minutes to fully deploy globally, unlike the other
resources in this project which deployed in seconds — documenting this since it's a genuinely
different operational characteristic worth knowing about.

**Next**: deploy the CloudFront distribution, update the ZAP scan target to the new CloudFront
URL (the real public entry point), and re-run the scan to confirm all Low findings are gone.

---

### Step 15 — CloudFront verified, ZAP re-targeted (✅ done)

Deployed the CloudFront distribution (`terraform apply` — 2 resources added: the response
headers policy and the distribution itself). Confirmed the fix directly with `curl` before
touching the scan again:

| Path | Status | Security headers present? |
|---|---|---|
| `/todos` (defined route) | 200 | ✅ Yes |
| `/` (undefined route) | 404 | ✅ Yes — this is the fix |
| `/favicon.ico` (undefined route) | 404 | ✅ Yes — this is the fix |

This confirms CloudFront is attaching the security headers **at the edge**, to every response
that passes through it — including the 404s that previously had no headers because they never
reached Lambda code. The structural gap found in Step 14 is now closed architecturally, not
worked around.

**New public entry point**: `https://dhf0667wobo63.cloudfront.net` — this replaces the raw API
Gateway URL as the "front door" to the API going forward. The API Gateway URL still works
directly (it's the CloudFront origin), but CloudFront is now the recommended way to reach it.

Updated `.github/workflows/security-scan.yml` to scan the CloudFront domain instead of the raw
API Gateway URL — testing the *actual* public entry point rather than an internal implementation
detail.

**Next**: push and confirm a fully clean ZAP scan (0 Low findings) against the new target.

---

## Cost Safety Notes
- AWS Budget alert set at $1 threshold (to be configured in Step 1)
- `terraform destroy` run between active demo/work sessions
- Lambda + API Gateway + DynamoDB usage kept within AWS Free Tier limits

## Repo Structure
```
secure-cloud-pipeline/
├── app/                  # Lambda function code
├── terraform/            # Infrastructure as Code
├── tests/                # Pytest test suite
├── .github/workflows/    # CI/CD pipeline (test + deploy + scan)
└── README.md             # This file — build log + documentation
```
