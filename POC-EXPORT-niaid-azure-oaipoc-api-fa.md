# POC Export - niaid-azure-oaipoc-api-fa

**Export Date**: December 26, 2025  
**Cleanup Completed**: December 26, 2025  
**Reason**: POC cleanup from DEV and PROD environments  
**Status**: ✅ Cleanup Complete - Archived for reference

---

## Overview

This document contains the exported configuration for the Azure OpenAI POC (Proof of Concept) components that were removed from the DEV APIM environment.

## Components

### 1. Backend: `niaid-azure-oaipoc-api-fa`

**Location**: `apimartifacts/backends/niaid-azure-oaipoc-api-fa/`

**Configuration**:
```json
{
  "properties": {
    "credentials": {
      "header": {
        "x-functions-key": [
          "{{niaid-azure-oaipoc-api-fa-key}}"
        ]
      }
    },
    "description": "niaid-azure-oaipoc-api-fa",
    "protocol": "http",
    "resourceId": "https://management.azure.com/subscriptions/18fc6b8b-44fa-47d7-ae51-36766ac67165/resourceGroups/nih-niaid-azure-oaipoc-rg/providers/Microsoft.Web/sites/niaid-azure-oaipoc-api-fa",
    "url": "https://niaid-azure-oaipoc-api-fa.azurewebsites.net/api"
  }
}
```

**Details**:
- **Type**: Azure Function App backend
- **URL**: https://niaid-azure-oaipoc-api-fa.azurewebsites.net/api
- **Resource Group**: nih-niaid-azure-oaipoc-rg
- **Authentication**: x-functions-key header using named value

---

### 2. Named Value: `niaid-azure-oaipoc-api-fa-key`

**Location**: `apimartifacts/named values/niaid-azure-oaipoc-api-fa-key/`

**Configuration**:
```json
{
  "properties": {
    "displayName": "niaid-azure-oaipoc-api-fa-key",
    "secret": true,
    "tags": [
      "key",
      "function",
      "auto"
    ]
  }
}
```

**Details**:
- **Type**: Secret named value
- **Purpose**: Function App authentication key
- **Secret Value**: `HUXdiZoafn2KuWuvkGIsTgh7g6T0rFnDFnr4437BXthsoEQMlxzPeA==`
- **Stored in Key Vault**: `kv-niaid-apim-dev` (secret name: `niaid-azure-oaipoc-api-fa-key`)

---

### 3. API: `itpms-chat-api`

**Location**: `apimartifacts/apis/itpms-chat-api/`

**Configuration (apiInformation.json)**:
```json
{
  "properties": {
    "path": "niaid-azure-oaipoc-api-fa",
    "displayName": "itpms-chat-api",
    "description": "Import from \"niaid-azure-oaipoc-api-fa\" Function App",
    "serviceUrl": "https://niaid-azure-oaipoc-api-fa.azurewebsites.net/api"
  }
}
```

**Operations**:
- `POST /httpexample` - Uses backend `niaid-azure-oaipoc-api-fa` via policy

**Policy Fragment** (`operations/post-httpexample/policy.xml`):
```xml
<set-backend-service id="apim-generated-policy" backend-id="niaid-azure-oaipoc-api-fa" />
```

---

## Dependencies

**APIs using this POC**:
- `itpms-chat-api` - Will be removed along with the POC backend

**Azure Resources** (External - not managed by this repository):
- Function App: `niaid-azure-oaipoc-api-fa` (in resource group `nih-niaid-azure-oaipoc-rg`)
- Resource Group: `nih-niaid-azure-oaipoc-rg`
- Application Insights: Multiple AI resources in the oaipoc resource group

---

## Removal Plan

1. ✅ Export configuration to this document
2. ✅ Remove API: `itpms-chat-api` from DEV APIM
3. ✅ Remove Backend: `niaid-azure-oaipoc-api-fa` from DEV APIM
4. ✅ Remove Named Value: `niaid-azure-oaipoc-api-fa-key` from DEV APIM
5. ✅ Remove from Key Vault: `kv-niaid-apim-dev`
6. ✅ Remove artifacts from repository (PR #8 merged)
7. ✅ Extract and deploy to PROD via GitOps (Workflow run 20526553111)

**Completion Details**:
- DEV deletions: December 26, 2025 14:45 UTC
- Repository cleanup: PR #8 merged December 26, 2025 14:47 UTC
- PROD deployment: Workflow run 20526553111 completed December 26, 2025 14:48 UTC
- Verification: Both DEV and PROD confirmed clean

---

## Notes

- This was a POC (Proof of Concept) for Azure OpenAI integration
- The Function App and resource group still exist in Azure but are no longer referenced by APIM in DEV or PROD
- All APIM references (API, backend, named value) have been removed from both environments
- The secret was removed from `kv-niaid-apim-dev` during cleanup
- If this POC needs to be reactivated, use this document to recreate the configuration
- **Azure Resources**: The Function App `niaid-azure-oaipoc-api-fa` in resource group `nih-niaid-azure-oaipoc-rg` may still exist and could be deleted if no longer needed

---

## Restoration Instructions (if needed)

To restore this POC configuration:

1. **Recreate Named Value**:
   ```bash
   az apim nv create \
     --service-name apim-daids-connect \
     --resource-group nih-niaid-avidpoc-dev-rg \
     --named-value-id niaid-azure-oaipoc-api-fa-key \
     --display-name niaid-azure-oaipoc-api-fa-key \
     --secret true \
     --value "{{secret-from-kv}}"
   ```

2. **Recreate Backend**: Copy backendInformation.json to `apimartifacts/backends/niaid-azure-oaipoc-api-fa/`

3. **Recreate API**: Copy the entire `itpms-chat-api` folder to `apimartifacts/apis/`

4. **Deploy**: Use the extractor/publisher workflow to sync with APIM
