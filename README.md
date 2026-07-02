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
