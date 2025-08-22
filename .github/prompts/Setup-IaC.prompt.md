---
mode: agent
---

# DevOps Master — Azure IaC & CI/CD (ASP.NET Core + Containers → Azure Container Apps or AKS)

## Assumptions
- Repo contains an ASP.NET Core web app (may include extra codes for frontend that could be in another language like react.js or angular it could have backend api project or other extra microservices).
- Use **Docker** for containerization, deploy to **Azure Container Apps (ACA)** or **Azure Kubernetes Service (AKS)**.
- Use **Azure Container Registry (ACR)**, **Azure Key Vault**, and one DB: **Azure SQL** or **Azure PostgreSQL** or **Cosmos DB**.
- Use **Azure Virtual Network** (+ **Application Gateway** if public ingress hardening needed), **Azure Monitor + Log Analytics + Application Insights**.
- **OIDC GitHub→Azure** is already configured for the repository with variables AZURE_CLIENT_ID, AZURE_SUBSCRIPTION_ID and AZURE_TENANT_ID set. you may use those secrets in GitHub Action for Logging into Azure using OIDC.
- **Managed Identity** is enabled for the Azure resources to allow secure access without credentials.
- **Azure CLI** is installed and configured in the GitHub Actions runner.
- **GitHub CLI** is installed and configured in the GitHub Actions runner.
- **Docker CLI and Docker-Compose** is installed. You may use these tools to build and test your containers locally before deploying to Azure.
- **Terraform CLI** is installed. You may use this tool to manage your infrastructure as code (IaC) deployments to Azure and validate your Infrastructure as Code (IaC) templates.


## Tools
- **@githubrepo** — create/update/commit files.
- **@github** — manage repo/environment secrets; run checks.
- **@azure** — query/subscriptions/RGs, validate/deploy Bicep, ACA ops.
- **@context7** and **@azure** — fetch latest best practices (summarize, no links).
- **@terraform** — manage Terraform configurations and state.
---

## Flow

### 1) Scan & Detect
- Scan for **`/docs/1.architecture.md`**. if the file exist, skip this step
- Scan repo for: ASP.NET Core projects, `Dockerfile`/`docker-compose`, database usage, static assets, tests and README.md to understand project structure and architecture.
- Infer architecture: single service vs multi-service. Prefer one container per service; single container for monolith. Deploy database as a separate service.
- Put everything into **`/docs/1.architecture.md`**. and go to next step in the flow.

### 2) Best Practices Doc
- Scan for **`/docs/2.best-practices.md`** . if the file exist, skip this step
- Read  **`/docs/1.architecture.md`** for the context of the research.
- Use **@context7** , **@azure** and **@terraform** to collect current guidance for Terraform, ACA, ACR, Key Vault, VNet/AppGW, Monitoring in Azure, GitHub Actions and Database options in Azure as well as other Infrastructure as Code best practices.
- Write concise summary (no links) to **`/docs/2.best-practices.md`** 

### 3) Implementation Plan
- Scan for **`/docs/3.implementation-plan.md`**. if the file exist, skip this step
- Read **`/docs/2.best-practices.md`** for the context of the research and **`/docs/1.architecture.md`** for the project architecture.
- Don't make assumptions and don't use prior knowledge on Infrastructure as Code or DevOPS or deployment or Secret management. Always use the best practices and project architecture you just fetched.
- Come up with Infrastructure as Code and CI/CDDeployment Implementation Plan:
  - Target Azure resources.
  - Terraform module list and parameters.
  - CI/CD jobs, triggers, environments.
  - Secret strategy (Use Azure Key Vault if possible).
  - Verify/rollback approach.
  - Make sure the deployment is idempotent and don't delete existing resources if redeployed and detect existing resources.
  - Double check the plan as well as latest documentations for terraform (you may use **@terraform** or **@context7** to inquire more)

- Write concise summary (no links) to **`/docs/3.implementation-plan.md`**.

### 4) Generate Terraform (modular, reusable)
- Create **`/infra`**:
  - `main.tf` orchestrator.
  - Modules:
    - `rg.tf` (if needed at sub scope).
    - `network.tf` (VNet, subnets, optional App Gateway + WAF).
    - `log-analytics.tf`.
    - `keyvault.tf` (+ access policies/role assignments; store generated secrets).
    - `acr.tf` (admin disabled; prefer MI-based pull).
    - `db.tf` (Azure SQL or PostgreSQL or Cosmos DB; private endpoint/firewall).
    - `aca-env.tf` (Managed Environment wired to Log Analytics).
    - `aca-app.tf` (container image, env vars, secrets refs, scale).
- Parameters:
  - `appName`, `environment`, `location`, `acrName`, `imageTag`, `dbChoice`, `tags`, etc.
- Secrets:
  - Mark sensitive params `@secure`.
  - Store DB credentials in Key Vault (generated or provided); app reads via secret ref or MI.
- Validation:
  - use terraform cli which is installed to validate templates.
  - Use **@azure** to `terraform plan`/`apply`.

### 5) GitHub Actions (CI/CD)
- Create **`.github/workflows/deploy.yml`**:
  - Triggers: `push` to `main` (or `master`), PRs to `main`, manual (`workflow_dispatch`).
  - Jobs:
    - `build`:
      - Checkout code.
      - Setup .NET, Node.js (if needed), Docker.
      - Restore/build/test/publish ASP.NET Core projects.
      - Build/push Docker image to ACR (tag with `${{ github.sha }}`).
      - Upload artifact (image tag).
    - `deploy` (needs `build`):
      - Checkout code.
      - Setup Azure CLI, Terraform CLI.
      - Download artifact (image tag).
      - Login to Azure via OIDC. Use variables AZURE_CLIENT_ID, AZURE_SUBSCRIPTION_ID and AZURE_TENANT_ID set in the repo secrets.
      - Create RG if not exist using **@azure** use the same name as in terraform variable.
      - Init/plan/apply Terraform in `/infra` with params (including image tag).
      - deploy to ACA/AKS.
      - setup database if and seed if doesn't exist.
      - Verify deployment (app running, ingress accessible, app connects to DB, reads secrets).
  - Environments: use GitHub Environments for `staging`, `production` with required reviewers if needed.
  - Permissions: least-privileged tokens; pin action versions.
  - Make sure to validate Terraform templates before applying.
  - Make sure deployment is idempotent and doesn't delete existing resources if redeployed (only reconfigure or modify if changed).
  - Use `terraform output` to extract and use resource IDs/URIs in subsequent steps.

### 6) Secrets & Config
- With **@github** and **@azure**, ensure repo/environment secrets or variables exist and GitHub pipeline has full access to deploy the resources to Azure Resource Group using OIDC Login and other best practices use github cli and azure cli to generate required secrets and store it in GitHub if necessary.
- Prefer Key Vault for app secrets; workflows should not echo secrets.
- Use **@azure** to create/update secrets in Key Vault.
- Do everything possible to avoid hardcoding secrets in the repository.
- Double check terraform templates and GitHub Actions workflows to ensure no secrets are hardcoded.
- Update GitHub Actions workflow to reference secrets from Key Vault via MI or GitHub Secrets as needed.
- Update app configuration to read from environment variables or Key Vault.
- Make sure the app can access Key Vault using Managed Identity without any credentials.
- Verify that the app can connect to the database using the credentials stored in Key Vault.
- Ensure that all sensitive information is handled securely throughout the deployment process.

### 7) Documentation
- Update **`/docs/4.setup-instructions.md`**:
  - Prerequisites (Azure subscription, OIDC setup).
  - Terraform init/plan/apply steps.
  - GitHub Actions workflow overview.
  - Accessing Key Vault secrets.
  - App access (ingress URL, DB connection).
  - Monitoring/logging setup.
  - Rollback steps (revert commit, re-apply).
  - Secret management strategy.
  - Maintenance tips (update image, scale app, rotate secrets).
  - Troubleshooting common issues.

### 8) Commit & PR
- Create a new branch `iac-setup` (or similar).
- Commit changes:
  - `/docs/1.architecture.md`
  - `/docs/2.best-practices.md`
  - `/docs/3.implementation-plan.md`
  - `/docs/4.setup-instructions.md`
  - `/infra/*` (Terraform files).
  - `/.github/workflows/deploy.yml`. 
- Undo and delete any temporary files or other artifacts that are not needed in the final commit.
- Push branch; create PR to `main` with description of changes.
- Review and merge the PR. No approval needed as you are the only contributor.

### 9) Testing & Verification
- At this point deployment should already be undergoing to Azure. Use **@github** to monitor the workflow run status.
- Use **@azure** to verify the deployment status and health of the resources.
- VERY IMPORTANT!: Don't finish or stop until this step is done. reiterate and put timer to double checl that everything is fully deployed and verified.
- Verify:
  - Terraform applied without errors; resources created as expected.
  - Azure resources exist: RG, VNet, ACR, Key Vault, DB, ACA/AKS.
  - ACA/AKS app is running; ingress URL accessible.
  - App connects to DB; reads secrets from Key Vault.
  - Logs/metrics in Azure Monitor, Application Insights.
  - If issues, check GitHub Actions logs, Terraform state, Azure resource status.

- Repeat steps 4-9 if needed to fix issues or improve setup.
- Keep iterating until everything is perfect and verified.
- Once verified, consider tagging the commit (e.g., `iac-setup-complete`).
- Document any issues under `/docs/5.issues.md` if needed to avoid repeating the same mistakes in the future and always check best practices for any updates or changes in the future. use @fetch , @context7 and @azure to fetch latest best practices and update the documentation if needed.


---

## Decision Rules
- Hosting: default **ACA** (single service → one app; multi → one per service).
- DB selection: prefer **Azure SQL** for EF/relational; use **PostgreSQL** if Npgsql found; use **Cosmos DB** if SDK detected.
- Ingress: start with ACA external. If stricter security needed, set ACA internal + **App Gateway**.
- Images: tag with `${{ github.sha }}`; keep immutable history.
- Security: OIDC only (no SP secrets), least-privileged tokens, pin action versions.
- Secrets: prefer **Key Vault**; use MI for app access; workflows avoid echoing secrets.
- Terraform: modular, reusable; validate before apply; idempotent (no resource deletion on reapply).
- CI/CD: single workflow with build + deploy jobs; use artifacts to pass image tag.

## Execute
- Perform steps 1→9 in order using @context7 @azure @githubrepo @github as specified.