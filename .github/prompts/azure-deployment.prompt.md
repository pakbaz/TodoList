# Azure Deployment Plan for TodoList Application

This plan follows Azure deployment best practices, the provided Bicep architecture, and the requirements of the TodoList project. Each step will be checked off as it is completed.

---

## ✅ 1. Analyze Service Requirements
- Review application architecture and Bicep template
- Confirm required Azure resources: Container Apps, PostgreSQL, Key Vault, Container Registry, Log Analytics, Application Insights, Managed Identity

## ⬜ 2. Generate/Update IaC Files
- [x] Bicep templates exist in `infra/` (main.bicep, main.parameters.json)
- [ ] Ensure all required parameters and modules are present and secure
- [ ] Add/validate comments and outputs for all key resources

## ⬜ 3. Create `azure.yaml` for AZD
- [ ] Generate `azure.yaml` at the workspace root for AZD deployment
- [ ] Define service, infra, and environment configuration

## ⬜ 4. Validate IaC and Pre-Deployment
- [ ] Run pre-deployment checks (`azd` predeploy or equivalent)
- [ ] Validate Bicep syntax and parameters

## ⬜ 5. Validate Quota & Region
- [ ] Check Azure region and quota for all resources

## ⬜ 6. Deploy to Azure
- [ ] Run `azd up` to provision infrastructure and deploy the app
- [ ] Monitor deployment for errors

## ⬜ 7. Post-Deployment Validation
- [ ] Check application health endpoint
- [ ] Validate MCP and REST endpoints
- [ ] Review logs and monitoring (App Insights, Log Analytics)

---

### Notes
- All secrets and credentials must be stored in Azure Key Vault or GitHub Secrets
- Use OIDC for GitHub Actions authentication
- Use managed identity for app-to-resource access
- All infra code is in `infra/` and app code in root

---

## Execution Log
- [x] Step 1: Requirements and architecture reviewed
- [ ] Step 2: IaC files validated and updated
- [ ] Step 3: `azure.yaml` created
- [ ] Step 4: Pre-deployment checks passed
- [ ] Step 5: Quota/region validated
- [ ] Step 6: Deployment succeeded
- [ ] Step 7: Post-deployment validation complete

---

_This plan will be updated and checked off as each step is executed._
