# DevOps Documentation

This document explains the Infrastructure as Code (Bicep) layout and CI/CD workflows.

## Bicep Structure
- `infra/main.bicep`: Orchestrates modules (Postgres, Key Vault, App Insights, App Service).
- `infra/modules/postgres.bicep`: Azure Database for PostgreSQL Flexible Server + database.
- `infra/modules/keyvault.bicep`: Key Vault (non-dev) storing Postgres password secret.
- `infra/modules/appinsights.bicep`: Application Insights instance (optional).
- `infra/modules/app.bicep`: App Service Plan + Linux Web App configured for container image & app settings.

### Parameters (main.bicep)
- `env`: Environment name.
- `location`: Azure region (defaults to RG location).
- `postgresAdminUser`, `postgresAdminPassword` (secure).
- `postgresSkuName`: DB SKU.
- `appServiceSkuName`, `appServiceSkuTier`.
- `imageRepo`, `imageTag` for container image.
- `enableAppInsights` toggle.

### Outputs
- `postgresServerName`, `postgresDatabase`, `webAppName`, `appServicePlanName`.

## GitHub Actions Workflows
### ci.yml
- Triggers: PR & push to main.
- Steps: checkout, setup .NET 9, cache NuGet, restore, build, test, build Bicep.

### deploy.yml
- Triggers: push changes to infra or manual dispatch.
- Auth: Azure OIDC (configure federated credentials in Azure AD for repo).
- Performs: Bicep build, what-if, create deployment, obtain web app name, health check loop.

### Required GitHub Secrets
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` for OIDC login.
- `ACR_LOGIN_SERVER` (e.g., myregistry.azurecr.io) if using existing ACR.
- (Optional) `POSTGRES_ADMIN_PASSWORD` to override generated password.

## Deployment Flow
1. Build & push container image separately (extend CI to push image once ACR established).
2. Manually run Deploy workflow specifying environment & image tag.
3. Template creates/updates resources; outputs retrieved.
4. Health check verifies `/health` endpoint.

## Local Testing
Run with Docker Compose: `docker compose up --build` then visit http://localhost:8080.

## Future Enhancements
- Add ACR module to IaC & image build/push in deploy workflow.
- Replace plain Postgres password with Key Vault secret reference in App Service.
- Add staging slot & slot swap.
- Implement Key Vault access policies / RBAC for Managed Identity.

Document version: 1.0
