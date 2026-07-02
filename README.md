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
