# Azure APIM GitOps - AI Agent Instructions

## Architecture Overview

This is a **GitOps repository for Azure API Management** using the Azure APIops Toolkit v6.0.2. The critical mental model: **repository artifacts come FROM source environment, configuration files are FOR deploying TO target environments**.

**Deployment Pipeline**: `DAIDS_DEV` (extract) → Repository → `DEV` (deploy + test) → `QA` → `PROD` (future)

### Environment Roles
- **DAIDS_DEV** (`apim-daids-connect`): Temporary source for extractions. Will be decommissioned once DEV is fully operational.
- **DEV** (`niaid-bpimb-apim-dev`): Primary deployment target, will become extraction source after DAIDS_DEV retirement.
- **QA** (`niaid-bpimb-apim-qa`): Testing environment, deploys after DEV validation passes.
- **PROD**: Future environment (not yet configured).

## Critical Cross-Environment Pattern

**Problem**: Extracted artifacts contain environment-specific resource IDs (logger references, diagnostics, backends) that won't work when deployed to other environments.

**Solution**: Standardized resource NAMES across all environments, with environment-specific VALUES.

**Example - Logger Configuration**:
```
Logger Name: "niaid-bpimb-apim-ai" (identical in DAIDS_DEV, DEV, QA)
Named Value Name: "apim-ai-connection-string" (identical in all environments)
Named Value VALUE: Different App Insights connection string per environment
```

**Why This Matters**: Azure APIops v6.0.2 does NOT support logger/diagnostic resource ID remapping via configuration.yaml files. The `configuration.dev.yaml` and `configuration.qa.yaml` files can override API properties (e.g., diagnostic verbosity) but CANNOT remap logger resource IDs. Standardized naming eliminates the need for unsupported remapping.

## Key Commands

**Extract from DAIDS_DEV**:
```bash
gh workflow run run-extractor.yaml -f CONFIGURATION_YAML_PATH="configuration.extractor.yaml"
```

**Deploy to environments** (automatic on merge to main):
```bash
git push origin main  # Triggers publisher workflow
```

**Manual full redeployment** (use sparingly - for disaster recovery):
```bash
gh workflow run run-publisher.yaml -f COMMIT_ID_CHOICE="publish-all-artifacts-in-repo"
```

**Check compliance** (Azure Advisor recommendations):
```bash
gh workflow run check-advisor.yaml
```

## Repository Structure Rules

### `apimartifacts/` - Source of Truth
- Contains artifacts extracted FROM DAIDS_DEV (currently)
- **Never manually edit** these files - they should reflect the source environment
- Standard resources that enable cross-environment deployment:
  - `loggers/niaid-bpimb-apim-ai/` - Standardized logger
  - `named values/apim-ai-connection-string/` - App Insights connection (secret, environment-specific value)

### Configuration Files
- `configuration.extractor.yaml` - Controls WHAT gets extracted from source APIM
- `configuration.dev.yaml` - Deployment overrides FOR deploying TO DEV
- `configuration.qa.yaml` - Deployment overrides FOR deploying TO QA

**Configuration file capabilities** (what they CAN and CANNOT do):
- ✅ Override API properties (diagnostic verbosity, rate limits)
- ✅ Replace backend URLs
- ✅ Token substitution for named values
- ❌ Remap logger resource IDs (not supported by APIops)
- ❌ Remap diagnostic logger references (not supported by APIops)

## Workflow Architecture

### Internal VNet Deployment
All APIM instances are in **Internal VNet mode** (private IPs only):
- DAIDS_DEV: `10.178.57.52` in `nih-niaid-azurestrides-dev-apim-az`
- DEV: `10.179.0.4` in `nih-niaid-azurestrides-bpimb-dev-apim-az`
- QA: `10.180.0.4` in `nih-niaid-azurestrides-bpimb-qa-apim-az`

**Testing Approach**: Ephemeral Azure VMs deployed into environment-specific VNets to reach private APIM gateways.

### Publisher Workflow Logic
1. **Deploy-To-DEV-With-Commit-ID**: Incremental deployment based on last commit
2. **Test-DEV-After-Deploy**: Validates deployment succeeded
3. **Deploy-To-QA**: Only runs if DEV tests pass
4. **Deploy-To-PROD**: Future environment (commented out)

## Common Patterns

### When Extracting Changes
After making changes in DAIDS_DEV APIM portal:
1. Run extractor workflow
2. Wait for PR creation (auto-generated)
3. Review PR changes (diagnostic references, resource IDs)
4. Merge PR → triggers automatic deployment to DEV

### When Changes Fail Publisher
**Symptom**: Publisher workflow fails with "resource not found" or "validation error"

**Common Causes**:
1. **Logger/Named Value mismatch**: Named value referenced in logger doesn't exist in target environment
   - **Fix**: Ensure named value exists in ALL environments with same NAME (different values OK)
2. **Resource ID references**: Artifact references source environment resource IDs
   - **Fix**: Use standardized resource names, not environment-specific IDs

### When Adding New Secrets
**Current pattern**: Inline secrets in APIM named values (marked as `"secret": true`)
**Future pattern**: Migrate to Key Vault references for better rotation and audit logging

**To migrate secret to Key Vault**:
1. Store secret in Key Vault: `az keyvault secret set --vault-name kv-<env> --name <secret-name> --value "<value>"`
2. Update named value to reference Key Vault: `"keyVault": {"secretIdentifier": "https://kv-<env>.vault.azure.net/secrets/<secret-name>"}`
3. Extract and redeploy

## Azure CLI Context

All Azure CLI commands use **service principal authentication** (configured in GitHub environment secrets):
- Subscription ID: `18fc6b8b-44fa-47d7-ae51-36766ac67165` (same for all environments)
- Resource groups vary by environment (see README Infrastructure section)
- Use `az rest` for operations not supported by `az apim` commands

## SOAP API Limitation

⚠️ **Azure APIops v6.0.2 does NOT support SOAP/WSDL APIs**. SOAP APIs must be managed manually in Azure Portal and are ignored by extractor/publisher.

## When Environment-Specific Values Are Needed

**Use named values with standardized names**:
- Create same named value NAME in all environments
- Store environment-specific VALUE (connection strings, endpoints, keys)
- Mark as `"secret": true` if sensitive
- Reference in policies/backends as `{{named-value-name}}`

**Example**: `apim-ai-connection-string` exists in DAIDS_DEV, DEV, QA with different App Insights connection strings.

## Security Compliance Monitoring

Weekly Azure Advisor compliance check runs automatically. High/Medium priority findings tracked in README Section 2.

**DAIDS_DEV Note**: Security issues in DAIDS_DEV are NOT being remediated (temporary environment scheduled for decommission). Focus security efforts on DEV, QA, PROD.

## Debugging Tools

**View workflow run logs**:
```bash
gh run view <run-id> --log
gh run view <run-id> --log-failed  # Only failed jobs
```

**Check artifact deployment**:
```bash
az rest --method get --uri "https://management.azure.com/subscriptions/.../providers/Microsoft.ApiManagement/service/<apim-name>/apis?api-version=2023-05-01-preview"
```

**Verify logger configuration**:
```bash
az rest --method get --uri "https://management.azure.com/.../loggers/<logger-name>?api-version=2023-05-01-preview"
```
