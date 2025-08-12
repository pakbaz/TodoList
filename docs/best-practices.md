# Azure Bicep & GitHub Actions Best Practices

This document captures opinionated best practices for this repository's infrastructure-as-code (IaC) and CI/CD.

## General Principles
- **Idempotent & Declarative**: All Azure resources described once in Bicep; no imperative drift scripts.
- **Modular Design**: Small focused Bicep modules (resource group scoped) composed by an environment template.
- **Parameterization**: All environment-variant values exposed as parameters w/ secure defaults.
- **Explicit Naming**: Deterministic names using: `<app><env><region><purpose>` pattern (shortened to stay within Azure length limits).
- **Security First**: No secrets in code. Use Key Vault & GitHub Secrets. Never commit connection strings with passwords.
- **Shift Left**: Validate Bicep (`bicep build/lint`) & templates (`what-if`) in CI prior to deployment.
- **Least Privilege**: Service principal used in GitHub Actions has only necessary role assignments (e.g., `Contributor` at RG scope + `Key Vault Secrets User` if reading secrets).
- **Fail Fast**: Health probe job after deploy; rollback guidance documented.

## Bicep Practices
- Use `existing` keyword for cross-resource references (e.g., existing Resource Group when subscription scoped deployment).
- Use `symbolicName` consistently & avoid hardcoded locations except central parameter default.
- Modules: `postgres.bicep`, `appservice.bicep` (or container app), `monitoring.bicep`, `keyvault.bicep`.
- Use secure parameters for passwords: `@secure()`.
- Tag all resources with: `project`, `env`, `owner`, `repository`, `costCenter` (optional), `createdBy=iac`.
- Apply firewall / network rules minimally (open for prototype, tighten later).
- Prefer `Azure Database for PostgreSQL Flexible Server` for managed Postgres. (Cheaper dev alt: `Basic` sku).
- Connection string assembled in App Service using Key Vault secret references or injected as App Settings.
- Enable diagnostic logs to Log Analytics workspace (centralized) when scaling beyond dev.

### Environments
Recommended environment stages: `dev`, `staging`, `prod`.
- Dev: small SKU, public exposure, optional Application Insights.
- Staging: mirrors production resource types, lower scale.
- Prod: scaling + backup retention + geo redundancy options (future).

## GitHub Actions Practices
- Reusable workflows for build & deploy to avoid duplication.
- Caching: use `actions/cache` for NuGet.
- Build: `dotnet restore`, `dotnet build --configuration Release`, `dotnet test`.
- Container image: build & push to Azure Container Registry (ACR) with content-addressable tags (git sha + semver).
- Deployment: `az deployment group create` with `what-if` preview.
- Use OIDC Federated Identity instead of stored service principal secret where possible.
- Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, plus optional `POSTGRES_ADMIN_PASSWORD` (or let template auto-generate & store in Key Vault).
- Protect production deploy job with: environment protection rules / manual approval.
- Add concurrency group per environment to avoid overlapping deploys.

## Observability & Ops
- Health endpoint: `/health` already implemented—used for post-deploy validation.
- Application Insights connection string provided via secret or automatically created resource.
- Dashboards & alerts (future): integrate in `monitoring.bicep`.

## Testing Strategy in CI
- Unit tests (service logic) with in-memory or SQLite provider.
- Migration tests (if EF migrations added later) verifying schema build.
- Infrastructure validation: `bicep lint` + `what-if` stage.

## Security Enhancements (Future)
- Private networking (VNet integration + private endpoint for Postgres + restricted ingress).
- Managed Identity for App Service; remove secrets usage.
- Key Vault referencing in App settings (`@Microsoft.KeyVault(SecretUri=...)`).

---
Document version: 1.0
