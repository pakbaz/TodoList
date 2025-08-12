---
mode: agent
---

# DevOps Master — Azure IaC & CI/CD (ASP.NET Core + Containers → Azure Container Apps)

## Assumptions
- Repo contains an ASP.NET Core web app (may include frontend/backend/microservices).
- Use **Docker** for containerization, deploy to **Azure Container Apps (ACA)**.
- Use **Azure Container Registry (ACR)**, **Azure Key Vault**, and one DB: **Azure SQL** or **Azure PostgreSQL** or **Cosmos DB**.
- Use **Azure Virtual Network** (+ **Application Gateway** if public ingress hardening needed), **Azure Monitor + Log Analytics**.
- **OIDC GitHub→Azure** is already configured.

## Tools
- **@githubrepo** — create/update/commit files.
- **@github** — manage repo/environment secrets; run checks.
- **@azure** — query/subscriptions/RGs, validate/deploy Bicep, ACA ops.
- **@context7** and **@azure** — fetch latest best practices (summarize, no links).

---

## Flow

### 1) Scan & Detect
- Scan repo for: ASP.NET Core projects, `Dockerfile`/`docker-compose`, database usage, static assets, tests.
- Infer architecture: single service vs multi-service. Prefer one ACA per service; single ACA for monolith.

### 2) Best Practices Doc
- Use **@context7** and **@azure** to collect current guidance for Bicep, ACA, ACR, Key Vault, VNet/AppGW, Monitor, GitHub Actions (OIDC, least-privilege, pin actions, caching).
- Write concise summary (no links) to **`/docs/best-practices.md`** via **@githubrepo**.

### 3) Implementation Plan
- Produce **`/docs/plan.md`** (brief):
  - Target Azure resources.
  - Bicep module list and parameters.
  - CI/CD jobs, triggers, environments.
  - Secret strategy (Key Vault + OIDC).
  - Verify/rollback approach (ACA revisions).
- Save with **@githubrepo**.

### 4) Generate Bicep (modular, reusable)
- Create **`/infra`**:
  - `main.bicep` orchestrator.
  - Modules:
    - `rg.bicep` (if needed at sub scope).
    - `network.bicep` (VNet, subnets, optional App Gateway + WAF).
    - `log-analytics.bicep`.
    - `keyvault.bicep` (+ access policies/role assignments; store generated secrets).
    - `acr.bicep` (admin disabled; prefer MI-based pull).
    - `db.bicep` (Azure SQL or PostgreSQL or Cosmos DB; private endpoint/firewall).
    - `aca-env.bicep` (Managed Environment wired to Log Analytics).
    - `aca-app.bicep` (container image, env vars, secrets refs, scale).
- Parameters:
  - `appName`, `environment`, `location`, `acrName`, `imageTag`, `dbChoice`, `tags`, etc.
- Secrets:
  - Mark sensitive params `@secure`.
  - Store DB credentials in Key Vault (generated or provided); app reads via secret ref or MI.
- Validation:
  - Use **@azure** to `bicep build`/`what-if`.

### 5) GitHub Actions (CI/CD)
Create `.github/workflows`:
- **`ci.yml`** (build/test/containerize/push):
  - Triggers: PRs + pushes.
  - Steps: checkout → setup-dotnet → restore/test → **Azure OIDC login** (`permissions: id-token: write`) → `az acr login` → docker build/tag (`${{ github.sha }}`) → push to ACR → set output `image_tag`.
  - Cache dependencies where safe.
- **`cd.yml`** (deploy IaC + app):
  - Trigger: push to `main` (and `workflow_dispatch`).
  - Environment protections (e.g., `staging`, `production`).
  - OIDC login → `az deployment group create` (or `azure/arm-deploy`) on `infra/main.bicep` with `imageTag` and env params.
  - Post-deploy health check: query ACA revision, optional HTTP probe.
  - On failure: swap to previous ACA revision (rollback).

### 6) Secrets & Config
- With **@github**, ensure repo/environment secrets or variables exist:
  - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RG_NAME`, `ACR_NAME`, `LOCATION`, `APP_NAME`, optional `DB_CHOICE`.
- Prefer Key Vault for app secrets; workflows should not echo secrets.

### 7) Documentation
- Create **`/docs/devops.md`**:
  - Architecture summary.
  - How to run CI/CD, envs, parameters.
  - How secrets flow (Key Vault + MI).
  - Rollback via ACA revisions.
- Save via **@githubrepo**.

### 8) Testing & Verification
- Syntax/lint: Bicep build; minimal `what-if`.
- Dry-run workflows (`workflow_dispatch`) on a test branch.
- Deploy to non-prod first; verify:
  - ACA revision Running, logs flowing to Log Analytics.
  - App responds on ingress (direct or via App Gateway).
  - DB connectivity OK (migrations run).

### 9) Commit & PR
- Use **@githubrepo** to commit all generated files with clear messages.
- Open PR (if branch) for review; then merge.

---

## Decision Rules
- Hosting: default **ACA** (single service → one app; multi → one per service).
- DB selection: prefer **Azure SQL** for EF/relational; use **PostgreSQL** if Npgsql found; use **Cosmos DB** if SDK detected.
- Ingress: start with ACA external. If stricter security needed, set ACA internal + **App Gateway**.
- Images: tag with `${{ github.sha }}`; keep immutable history.
- Security: OIDC only (no SP secrets), least-privileged tokens, pin action versions.

## Execute
- Perform steps 1→9 in order using @context7 @azure @githubrepo @github as specified.