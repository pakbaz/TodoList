# Infrastructure & CI/CD Plan

This plan outlines the Azure resources, Bicep module structure, parameters, and GitHub Actions workflows for the TodoList application.

## 1. Target Azure Architecture
Resources per environment (dev/staging/prod):
- Resource Group
- Azure Container Registry (ACR) (shared across env or per env; we'll deploy once in `dev` template then mark existing for others)
- App Service Plan (Linux) + Web App (container-based) OR Azure Container Apps (future). We'll use Linux Web App for simplicity.
- Azure Database for PostgreSQL Flexible Server
- Key Vault (store DB admin password + Application Insights connection string if needed)
- Application Insights (optional dev, enabled staging/prod)
- (Future) Log Analytics Workspace for central logs

## 2. Naming Conventions
Format: `todolist-<env>-<region>-<res>` (example: `todolist-dev-eastus-rg`). Region default: `eastus`.

## 3. Bicep Module Layout
infra/
- main.bicep (environment entry point) parameters: env, location, postgresAdminUser, postgresAdminPassword (secure), skuTier, skuName
- modules/resourceGroup.bicep (optional if deploying at subscription scope)
- modules/postgres.bicep
- modules/app.bicep (App Service + plan + container config + app settings)
- modules/keyvault.bicep
- modules/appinsights.bicep

## 4. Secrets & Configuration Flow
- Postgres admin password passed as secure parameter or generated (using simple unique string) and output to Key Vault secret.
- Connection string constructed in main and exported as output; also stored in Key Vault.
- App Service gets settings: `ASPNETCORE_ENVIRONMENT`, `ConnectionStrings__DefaultConnection` (value referencing Key Vault secret in future; for now plain string in dev, Key Vault in staging/prod via secret reference).

## 5. GitHub Actions Workflows
### Workflows
1. ci.yml (trigger: push PR) — restore, build, test, build container image, push to ACR (on main only). Validates Bicep (lint + build).
2. deploy.yml (trigger: push to main & manual dispatch w/ env input) — assumes image already pushed; runs what-if then deploy; sets Web App container image; runs health check.
3. reusable-build.yml (reusable) — dotnet build/test with cache (used by ci and deploy).

### OIDC Auth
Use `azure/login@v2` with Federated Credentials (user must configure in Azure AD). Required secrets: subscription, tenant, client id (not secret).

### Environment Protection
`environment: prod` uses required reviewers (configured manually in repo settings).

## 6. Validation Steps
- Bicep build (compile) to ensure syntax.
- `az deployment group what-if` preview.
- Post-deploy: curl health endpoint until 200 or timeout (fail job if unhealthy).

## 7. Testing Strategy
Add test project `TodoList.Tests` to validate `TodoListService` basic behaviors using in-memory SQLite.

## 8. Next Steps (Future Enhancements)
- VNet integration & restricted IP access.
- Key Vault secret references instead of plain secrets for dev.
- Add CodeQL and Dependabot alerts.

Document version: 1.0
