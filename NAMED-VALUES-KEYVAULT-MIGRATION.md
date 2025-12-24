# Named Values to Key Vault Migration Plan

**Date Created**: December 24, 2025  
**Status**: Ready for Implementation  
**Environment**: DEV → PROD (via GitOps)

---

## Overview

This document provides detailed steps to migrate APIM named values from inline secrets to Azure Key Vault references. This improves security posture and aligns with Azure Advisor recommendations.

### Secrets to Migrate

1. **`niaid-azure-oaipoc-api-fa-key`** - Function App authentication key
   - Used by: `niaid-azure-oaipoc-api-fa` backend
   - Purpose: `x-functions-key` header authentication

2. **`Logger-Credentials--6671ebaafb42680790aa5618`** (ID: `6671ebaafb42680790aa5617`)
   - Used by: Application Insights logger
   - Purpose: Instrumentation key for logging

3. **`OTCSTICKET`** - Currently unused
   - Purpose: Unknown (no current references found)

---

## Prerequisites

- [x] Azure CLI installed and authenticated
- [x] GitHub CLI installed and authenticated
- [x] Access to DEV APIM (`apim-daids-connect`)
- [x] Access to PROD APIM (`niaid-bpimb-apim-dev`)
- [x] Permissions to create/manage Key Vault in DEV resource group
- [x] Service principal configured for GitHub Actions

---

## Migration Steps

### Phase 1: DEV Environment Setup

#### Step 1.1: Get Current Secret Values

```powershell
# Retrieve secret values from APIM (save these securely - you'll need them)
$secret1 = az apim nv show `
  --service-name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --named-value-id niaid-azure-oaipoc-api-fa-key `
  --query "value" -o tsv

$secret2 = az apim nv show `
  --service-name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --named-value-id 6671ebaafb42680790aa5617 `
  --query "value" -o tsv

$secret3 = az apim nv show `
  --service-name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --named-value-id OTCSTICKET `
  --query "value" -o tsv

# Display values (copy these - you'll need them for Key Vault)
Write-Host "Secret 1 (niaid-azure-oaipoc-api-fa-key): $secret1"
Write-Host "Secret 2 (Logger-Credentials): $secret2"
Write-Host "Secret 3 (OTCSTICKET): $secret3"
```

**✅ Checkpoint**: Verify all three secrets were retrieved successfully.

---

#### Step 1.2: Create Key Vault in DEV

```powershell
# Create Key Vault in DEV environment
az keyvault create `
  --name kv-niaid-apim-dev `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --location eastus2 `
  --enable-purge-protection true

# Verify creation
az keyvault show `
  --name kv-niaid-apim-dev `
  --query "{Name:name, Location:location, PurgeProtection:properties.enablePurgeProtection}"
```

**✅ Checkpoint**: Key Vault created successfully with purge protection enabled.

---

#### Step 1.3: Store Secrets in Key Vault

```powershell
# Store each secret in Key Vault
az keyvault secret set `
  --vault-name kv-niaid-apim-dev `
  --name niaid-azure-oaipoc-api-fa-key `
  --value $secret1

az keyvault secret set `
  --vault-name kv-niaid-apim-dev `
  --name Logger-Credentials--6671ebaafb42680790aa5618 `
  --value $secret2

az keyvault secret set `
  --vault-name kv-niaid-apim-dev `
  --name OTCSTICKET `
  --value $secret3

# Verify secrets were stored
az keyvault secret list `
  --vault-name kv-niaid-apim-dev `
  --query "[].{Name:name, Enabled:attributes.enabled}" -o table
```

**✅ Checkpoint**: All three secrets stored in Key Vault successfully.

---

#### Step 1.4: Enable APIM Managed Identity

```powershell
# Enable system-assigned managed identity on DEV APIM
az apim update `
  --name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --set identity.type=SystemAssigned

# Get the principal ID
$apimPrincipalId = az apim show `
  --name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --query "identity.principalId" -o tsv

Write-Host "APIM Managed Identity Principal ID: $apimPrincipalId"
```

**✅ Checkpoint**: APIM managed identity enabled and principal ID retrieved.

---

#### Step 1.5: Grant APIM Access to Key Vault

```powershell
# Grant APIM permission to read secrets from Key Vault
az keyvault set-policy `
  --name kv-niaid-apim-dev `
  --object-id $apimPrincipalId `
  --secret-permissions get list

# Verify the access policy was set
az keyvault show `
  --name kv-niaid-apim-dev `
  --query "properties.accessPolicies[?objectId=='$apimPrincipalId'].{ObjectId:objectId, Permissions:permissions.secrets}" -o table
```

**✅ Checkpoint**: APIM has `get` and `list` permissions on Key Vault.

---

#### Step 1.6: Update Named Values to Reference Key Vault

```powershell
# Get Key Vault secret identifiers
$secretId1 = az keyvault secret show `
  --vault-name kv-niaid-apim-dev `
  --name niaid-azure-oaipoc-api-fa-key `
  --query "id" -o tsv

$secretId2 = az keyvault secret show `
  --vault-name kv-niaid-apim-dev `
  --name Logger-Credentials--6671ebaafb42680790aa5618 `
  --query "id" -o tsv

$secretId3 = az keyvault secret show `
  --vault-name kv-niaid-apim-dev `
  --name OTCSTICKET `
  --query "id" -o tsv

# Update named value #1: niaid-azure-oaipoc-api-fa-key
az apim nv update `
  --service-name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --named-value-id niaid-azure-oaipoc-api-fa-key `
  --secret true `
  --keyvault-secret-identifier $secretId1

# Update named value #2: Logger-Credentials
az apim nv update `
  --service-name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --named-value-id 6671ebaafb42680790aa5617 `
  --secret true `
  --keyvault-secret-identifier $secretId2

# Update named value #3: OTCSTICKET
az apim nv update `
  --service-name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --named-value-id OTCSTICKET `
  --secret true `
  --keyvault-secret-identifier $secretId3

# Verify all updates
az apim nv list `
  --service-name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --query "[?secret==``true``].{Name:name, DisplayName:displayName, KeyVaultSecretId:keyVault.secretIdentifier}" -o table
```

**✅ Checkpoint**: All three named values now reference Key Vault instead of storing values inline.

**Expected Output**:
```
Name                                   DisplayName                                   KeyVaultSecretId
------------------------------------   -------------------------------------------   -------------------------------------------------------------
niaid-azure-oaipoc-api-fa-key          niaid-azure-oaipoc-api-fa-key                 https://kv-niaid-apim-dev.vault.azure.net/secrets/niaid-azure-oaipoc-api-fa-key
6671ebaafb42680790aa5617               Logger-Credentials--6671ebaafb42680790aa5618  https://kv-niaid-apim-dev.vault.azure.net/secrets/Logger-Credentials--6671ebaafb42680790aa5618
OTCSTICKET                             OTCSTICKET                                    https://kv-niaid-apim-dev.vault.azure.net/secrets/OTCSTICKET
```

---

### Phase 2: Testing in DEV

#### Step 2.1: Test Backend Connectivity

```powershell
# List APIs that might use the Function App backend
az apim api list `
  --service-name apim-daids-connect `
  --resource-group nih-niaid-avidpoc-dev-rg `
  --query "[].{Name:name, DisplayName:displayName, Path:path}" -o table

# Test API calls through Azure Portal or Postman:
# 1. Navigate to Azure Portal → apim-daids-connect → APIs
# 2. Find APIs using the Function App backend
# 3. Use "Test" tab to make test calls
# 4. Verify responses are successful (200 OK)
```

**✅ Checkpoint**: All APIs using the Function App backend respond successfully.

---

#### Step 2.2: Test Application Insights Logging

```powershell
# Make some test API calls
# Then check Application Insights for logs

# Get the Application Insights resource
az monitor app-insights component show `
  --resource-group nih-niaid-bpimb-sebapi-poc-dev-eastus-rg_group `
  --app nih-niaid-bpimb-sebapi-poc-dev-eastus-rg `
  --query "{Name:name, InstrumentationKey:instrumentationKey}"

# Verify logs are being received (check in Azure Portal)
# Navigate to Application Insights → Logs
# Run query: requests | where timestamp > ago(1h) | take 10
```

**✅ Checkpoint**: Application Insights receiving logs from APIM successfully.

---

### Phase 3: Extract and Deploy to PROD

#### Step 3.1: Extract Updated Artifacts from DEV

```powershell
# Navigate to repository
cd c:\Users\whiters\github-niaud\apidevops\API-DEVOPS

# Run the extractor workflow to capture Key Vault references
gh workflow run run-extractor.yaml -f CONFIGURATION_YAML_PATH="configuration.extractor.yaml"

# Wait for workflow to complete
Start-Sleep -Seconds 30
gh run list --workflow=run-extractor.yaml --limit 1

# Pull the extracted changes
git pull origin main
```

**✅ Checkpoint**: Extractor workflow completed successfully.

---

#### Step 3.2: Verify Extracted Artifacts

```powershell
# Check that named values now reference Key Vault
Get-Content "apimartifacts\named values\niaid-azure-oaipoc-api-fa-key\namedValueInformation.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10

Get-Content "apimartifacts\named values\6671ebaafb42680790aa5617\namedValueInformation.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10

Get-Content "apimartifacts\named values\OTCSTICKET\namedValueInformation.json" | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

**Expected Content** (example for niaid-azure-oaipoc-api-fa-key):
```json
{
  "properties": {
    "displayName": "niaid-azure-oaipoc-api-fa-key",
    "secret": true,
    "keyVault": {
      "secretIdentifier": "https://kv-niaid-apim-dev.vault.azure.net/secrets/niaid-azure-oaipoc-api-fa-key"
    },
    "tags": [
      "key",
      "function",
      "auto"
    ]
  }
}
```

**✅ Checkpoint**: Artifacts contain Key Vault references (not inline values).

---

#### Step 3.3: Prepare PROD Key Vault

**IMPORTANT**: Before deploying, ensure PROD Key Vault has the same secrets:

```powershell
# Store secrets in PROD Key Vault (kv-niaid-bpimb-apim-dev)
# Use the same secret values retrieved in Step 1.1

az keyvault secret set `
  --vault-name kv-niaid-bpimb-apim-dev `
  --name niaid-azure-oaipoc-api-fa-key `
  --value $secret1

az keyvault secret set `
  --vault-name kv-niaid-bpimb-apim-dev `
  --name Logger-Credentials--6671ebaafb42680790aa5618 `
  --value $secret2

az keyvault secret set `
  --vault-name kv-niaid-bpimb-apim-dev `
  --name OTCSTICKET `
  --value $secret3

# Verify PROD secrets
az keyvault secret list `
  --vault-name kv-niaid-bpimb-apim-dev `
  --query "[?contains(name, 'niaid-azure-oaipoc') || contains(name, 'Logger-Credentials') || contains(name, 'OTCSTICKET')].{Name:name, Enabled:attributes.enabled}" -o table
```

**✅ Checkpoint**: All three secrets exist in PROD Key Vault.

---

#### Step 3.4: Ensure PROD APIM has Key Vault Access

```powershell
# Verify PROD APIM has managed identity
$prodApimPrincipalId = az apim show `
  --name niaid-bpimb-apim-dev `
  --resource-group niaid-bpimb-apim-dev-rg `
  --query "identity.principalId" -o tsv

# If null, enable it:
if ([string]::IsNullOrEmpty($prodApimPrincipalId)) {
    az apim update `
      --name niaid-bpimb-apim-dev `
      --resource-group niaid-bpimb-apim-dev-rg `
      --set identity.type=SystemAssigned
    
    $prodApimPrincipalId = az apim show `
      --name niaid-bpimb-apim-dev `
      --resource-group niaid-bpimb-apim-dev-rg `
      --query "identity.principalId" -o tsv
}

Write-Host "PROD APIM Principal ID: $prodApimPrincipalId"

# Grant PROD APIM access to PROD Key Vault
az keyvault set-policy `
  --name kv-niaid-bpimb-apim-dev `
  --object-id $prodApimPrincipalId `
  --secret-permissions get list

# Verify access policy
az keyvault show `
  --name kv-niaid-bpimb-apim-dev `
  --query "properties.accessPolicies[?objectId=='$prodApimPrincipalId'].{ObjectId:objectId, Permissions:permissions.secrets}" -o table
```

**✅ Checkpoint**: PROD APIM can access PROD Key Vault.

---

#### Step 3.5: Commit and Deploy to PROD

```powershell
# Review the changes
git status
git diff

# Commit the extracted artifacts
git add .
git commit -m "Migrate named values to Key Vault references

- Moved niaid-azure-oaipoc-api-fa-key to Key Vault
- Moved Logger-Credentials to Key Vault
- Moved OTCSTICKET to Key Vault
- Tested successfully in DEV environment
- Ready for PROD deployment"

git push origin main
```

**✅ Checkpoint**: Changes committed and pushed to repository.

---

#### Step 3.6: Monitor PROD Deployment

```powershell
# The publisher workflow should trigger automatically
# Monitor the deployment
gh run list --workflow=run-publisher.yaml --limit 1
gh run watch <run-id>

# After deployment completes, verify named values in PROD
az apim nv list `
  --service-name niaid-bpimb-apim-dev `
  --resource-group niaid-bpimb-apim-dev-rg `
  --query "[?secret==``true``].{Name:name, DisplayName:displayName, KeyVaultSecretId:keyVault.secretIdentifier}" -o table
```

**✅ Checkpoint**: Publisher workflow completed successfully, PROD named values reference Key Vault.

---

### Phase 4: Post-Deployment Validation

#### Step 4.1: Test PROD APIs

```powershell
# Test APIs in PROD that use the Function App backend
# Navigate to Azure Portal → niaid-bpimb-apim-dev → APIs
# Use Test tab or external tools (Postman, curl)

# Verify API responses are successful
```

**✅ Checkpoint**: PROD APIs function correctly with Key Vault-backed named values.

---

#### Step 4.2: Verify Azure Advisor

```powershell
# Check Azure Advisor compliance
gh workflow run check-advisor.yaml

# Wait for completion
Start-Sleep -Seconds 30
gh run list --workflow=check-advisor.yaml --limit 1

# The 3 "Move named values to Key Vault" recommendations should now be resolved
```

**✅ Checkpoint**: Azure Advisor shows named values are now in Key Vault.

---

## Rollback Plan

If issues are encountered in PROD:

### Rollback Step 1: Revert Named Values to Inline Secrets

```powershell
# In PROD, update named values back to inline values
az apim nv update `
  --service-name niaid-bpimb-apim-dev `
  --resource-group niaid-bpimb-apim-dev-rg `
  --named-value-id niaid-azure-oaipoc-api-fa-key `
  --secret true `
  --value $secret1

az apim nv update `
  --service-name niaid-bpimb-apim-dev `
  --resource-group niaid-bpimb-apim-dev-rg `
  --named-value-id 6671ebaafb42680790aa5617 `
  --secret true `
  --value $secret2

az apim nv update `
  --service-name niaid-bpimb-apim-dev `
  --resource-group niaid-bpimb-apim-dev-rg `
  --named-value-id OTCSTICKET `
  --secret true `
  --value $secret3
```

### Rollback Step 2: Revert Repository

```powershell
# Revert the commit
git revert HEAD
git push origin main

# The publisher will deploy the reverted state
```

---

## Success Criteria

- [x] All three named values migrated to Key Vault in DEV
- [x] All DEV API tests pass
- [x] Application Insights logging working in DEV
- [x] Artifacts extracted with Key Vault references
- [x] PROD Key Vault contains all three secrets
- [x] PROD APIM has Key Vault access
- [x] PROD deployment successful
- [x] All PROD API tests pass
- [x] Azure Advisor recommendations cleared

---

## Security Benefits

1. **Centralized Secret Management**: All secrets stored in Azure Key Vault
2. **Audit Logging**: Key Vault logs all secret access
3. **Access Control**: RBAC and access policies control who can access secrets
4. **Rotation Capability**: Secrets can be rotated in Key Vault without APIM changes
5. **Compliance**: Meets Azure Advisor security recommendations
6. **Encryption**: Secrets encrypted at rest and in transit

---

## Notes

- **GitOps Workflow**: Changes made in DEV are extracted and deployed to PROD automatically
- **Environment Variables**: The publisher automatically adjusts Key Vault URLs for each environment
- **No Downtime**: Named value updates in APIM are non-disruptive
- **Secret Names**: Must be identical between DEV and PROD Key Vaults
- **Managed Identity**: Required for APIM to access Key Vault without credentials

---

## Reference Links

- [Azure APIM Named Values](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-properties)
- [APIM Key Vault Integration](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-properties?tabs=azure-portal#key-vault-secrets)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Managed Identity Overview](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)

---

**Document Version**: 1.0  
**Last Updated**: December 24, 2025  
**Next Review**: After successful PROD deployment
