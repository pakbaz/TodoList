---
mode: agent
---

# DevOps Master — Azure IaC & CI/CD (ASP.NET Core + Containers → Azure Container Apps or AKS)

## Assumptions
- Repo contains an ASP.NET Core web app (may include extra codes for frontend that could be in another language like react.js or angular it could have backend api project or other extra microservices).
- Use **Docker** for containerization, deploy to **Azure Container Apps (ACA)** or **Azure Kubernetes Service (AKS)**.
- Use **Azure Container Registry (ACR)**, **Azure Key Vault**, and one DB: **Azure SQL** or **Azure PostgreSQL** or **Cosmos DB**.
- **OIDC GitHub→Azure** is already configured for the repository with variables AZURE_CLIENT_ID, AZURE_SUBSCRIPTION_ID and AZURE_TENANT_ID set. you may use those secrets in GitHub Action for Logging into Azure using OIDC.
- **Managed Identity** is enabled for the Azure resources to allow secure access without credentials.
- **Azure CLI** is installed and configured in the GitHub Actions runner.
- **GitHub CLI** is installed and configured in the GitHub Actions runner.
- **Docker CLI and Docker-Compose** is installed. You may use these tools to build and test your containers locally before deploying to Azure.


## Tools
- **@githubrepo** — create/update/commit files.
- **@github** — manage repo/environment secrets; run checks.
- **@azure** — query/subscriptions/RGs, validate/deploy Bicep, ACA ops.
- **@context7** and **@azure** — fetch latest best practices (summarize, no links).
- **@microsoft-docs** — query Microsoft Docs for specific guidance.
- **@fetch** — retrieve code snippets and examples.
---

## Flow

### 1) Scan & Detect
- Scan for **`/docs/1.architecture.md`**. if the file exist, skip this step
- Scan repo for: ASP.NET Core projects, Dockerfile, docker-compose, database usage, static assets, tests and README.md to understand project structure and architecture.
- Infer architecture: single service vs multi-service. Prefer one container per service; single container for monolith. Deploy database as a separate service.
- Put everything into **`/docs/1.architecture.md`**. and go to next step in the flow.

### 2) Best Practices and Implementation plan Doc
- Scan for **`/docs/2.implementation-plan.md`** . if the file exist, skip this step
- Read  **`/docs/1.architecture.md`** for the context of the research.
- Use **@context7** , **@azure** and **@microsoft-docs** to collect current guidance for AKS, ACA, ACR, Key Vault, Monitoring in Azure, GitHub Actions and Database options in Azure as well as other Infrastructure as Code best practices.
- Come up with Infrastructure as Code and CI/CDDeployment Implementation Plan:
  - Target Azure resources.
  - Define resource dependencies and order of operations.
  - CI/CD jobs, triggers, environments.
  - Secret strategy (Use Azure Key Vault if possible).
  - Verify/rollback approach.
  - Make sure the deployment is idempotent and don't delete existing resources if redeployed.
  - Use Bicep Modular Templates for reusable components.
  - Implement parameterized templates for environment-specific configurations.
  - Write concise summary (no links) to **`/docs/2.implementation-plan.md`**.

- double check the implementation plan for completeness and accuracy.

### 3) Generate Infrastructure using Azure Bicep
- Scan for **`/infra`** directory. If it exists, skip this step.
- Use `/docs/2.implementation-plan.md` as a guide to create Bicep templates for the infrastructure.
- Implement Bicep modules for reusable components.
- Use Bicep parameter files for environment-specific configurations.
- Implement Bicep outputs for cross-module references.
- put everything under `/infra` directory. Put modules in `/infra/modules` and main Bicep file in `/infra/main.bicep`.
- verify and validate the Bicep templates for syntax and best practices.

### 4) GitHub Actions (CI/CD) and setup secrets
- Create **`.github/workflows/deploy.yml`** :
- make sure for the first time infrastructure is provisioned before application deployment.
- create a job for infrastructure deployment using Bicep
- use `az deployment group create` command to deploy the Bicep template.
- create a job for application deployment using GitHub Actions.
- build and push Docker image to ACR (once created).
- deploy the application to Azure Container Apps.

### 5) Commit, PR, Deploy, and Verify
- Create a branch `iac-setup` (or similar).
- Commit changes:
  - `/docs/1.architecture.md`
  - `/docs/2.implementation-plan.md`
  - `/infra/*` (IaC templates: Bicep)
  - `/.github/workflows/deploy.yml`
- Remove any temporary files or artifacts not needed in the final commit.
- Push the branch and open a PR to `main` with a concise description of the changes.
- Review and merge the PR (self-approve if you are the only contributor).
- After merge, deployment should start automatically:
  - Use **@github** to monitor the workflow run and logs until completion.
  - Use **@azure** to verify resource provisioning and application health.
- Verification checklist (adapt based on your architecture; mark N/A where not used):
  - Azure resources exist: RG, VNet (if used), ACR, Key Vault (if used), DB (PostgreSQL/SQL/Cosmos), ACA/AKS.
  - App is running in ACA/AKS; external ingress URL is reachable (HTTP 200/OK).
  - App connects to the database; secrets are provided via Key Vault or environment (prefer Key Vault).
  - Logs/metrics are flowing to Log Analytics and/or Application Insights.
- If anything fails:
  - fix the bicep templates, make sure the 
  - Fix forward with small commits on the same branch and re-run the workflow.
- When fully verified:
  - Tag the commit (e.g., `iac-setup-complete`).
  - Optionally add `/docs/5.issues.md` to record lessons learned and periodically refresh best practices using **@fetch**, **@context7**, and **@azure**.
- Do not stop until the app is deployed, verified, and the PR is merged.
- verification: ensure all resources are provisioned and the application is running as expected.
- iteration: incorporate feedback and make necessary adjustments.

## Decision Rules
- Hosting: default **ACA** (single service → one app; multi → one per service).
- DB selection: prefer **Azure SQL** for EF/relational; use **PostgreSQL** if Npgsql found; use **Cosmos DB** if SDK detected.
- Ingress: start with ACA external. If stricter security needed, set ACA internal + **App Gateway**.
- Images: tag with `${{ github.sha }}`; keep immutable history.
- Security: OIDC only (no SP secrets), least-privileged tokens, pin action versions.
- Secrets: prefer **Key Vault**; use MI for app access; workflows avoid echoing secrets.
- CI/CD: single workflow with build + deploy jobs; use artifacts to pass image tag.

## Execute
- Perform steps 1→5 in order using @context7 @azure @githubrepo @github as specified. Don't Skip any steps and In the last step make sure you verify everything.
- In the last step, ensure all resources are provisioned and the application is running as expected.