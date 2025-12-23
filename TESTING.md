# API Testing Documentation

## Overview

This repository contains automated workflows for testing Azure API Management (APIM) endpoints across development and production environments.

## Workflows

### 1. Test - APIs (`test-apis.yaml`)

Standard API testing workflow that runs on GitHub-hosted or self-hosted runners.

**Features:**
- Health check testing (validates APIM gateway is responding)
- Endpoint availability testing (validates individual API endpoints)
- Full test suite (combines all tests)
- Cross-platform PowerShell support

**Usage:**
```bash
# Test prod environment (uses GitHub-hosted runners)
gh workflow run test-apis.yaml -f ENVIRONMENT=prod -f TEST_TYPE=health-check

# Test specific API in prod
gh workflow run test-apis.yaml -f ENVIRONMENT=prod -f TEST_TYPE=endpoint-availability -f API_NAME=echo-api

# Run full test suite
gh workflow run test-apis.yaml -f ENVIRONMENT=prod -f TEST_TYPE=full-suite
```

**Status:**
- ✅ Prod: Fully functional with GitHub-hosted runners
- ⚠️ Dev: Requires self-hosted runner (APIM is in internal VNet)

### 2. Test - APIs (Ephemeral) (`test-apis-ephemeral.yaml`)

Advanced workflow that creates a temporary Azure VM in the internal VNet for testing.

**How it works:**
1. **Create VM**: Provisions a Standard_B1s Ubuntu VM in the same VNet as the internal APIM
2. **Run Tests**: Executes API tests from within the VM using `az vm run-command`
3. **Cleanup**: Automatically deletes the VM regardless of test outcome

**Features:**
- No persistent infrastructure required
- Tests internal APIM endpoints from within VNet
- Automatic resource cleanup
- Network diagnostics included

**Usage:**
```bash
# Test dev environment
gh workflow run test-apis-ephemeral.yaml -f ENVIRONMENT=dev -f TEST_TYPE=health-check

# Test specific API in dev
gh workflow run test-apis-ephemeral.yaml -f ENVIRONMENT=dev -f TEST_TYPE=endpoint-availability -f API_NAME=opentext
```

**Status:**
- ✅ Infrastructure: VM creation/deletion working
- ⚠️ DNS Issue: Internal APIM hostname not resolving within VNet

## Environments

### Production Environment
- **APIM Gateway**: `niaid-bpimb-apim-dev.azure-api.net`
- **Network Type**: External (currently public)
- **Testing Method**: GitHub-hosted runners
- **Status**: ✅ Fully operational

### Development Environment
- **APIM Gateway**: `apim-daids-connect.azure-api.net`
- **Network Type**: Internal VNet
- **VNet**: `nih-niaid-azurestrides-dev-apim-az`
- **Subnet**: `niaid-apim` (APIM), `niaid-commonservices-test` (test VMs)
- **Testing Method**: Ephemeral Azure VMs
- **Status**: ⚠️ DNS configuration needed

## APIs Under Test

1. `crms-api-qa`
2. `demo-conference-api`
3. `echo-api`
4. `itpms-chat-api`
5. `merlin-db`
6. `opentext`
7. `otcs-mcp-server`
8. `test`

## Test Types

### Health Check
Validates that the APIM gateway is responding. Accepts HTTP 404, 401, or 403 as healthy responses.

### Endpoint Availability
Tests each API endpoint to verify it's reachable. Accepts HTTP 200, 401, 403, or 404 as successful responses.

### Full Suite
Runs both health check and endpoint availability tests.

## Azure Permissions

### Service Principal Setup

The workflows use separate service principals for dev and prod environments, stored as GitHub environment secrets:

- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

### Required Permissions

**For ephemeral VM workflow:**
- Contributor role on the resource group where VMs will be created
- Contributor role on the VNet resource group (for cross-RG subnet access)

**Granted permissions:**
```bash
# Service principal: github-apidevops-workflow (a763a856-d2ae-43ab-b686-0cf24a5da690)
# Resource group: nih-niaid-azurestrides-dev-rg-admin-az
# Role: Contributor
```

## Known Issues

### Dev Environment DNS Resolution

**Problem:**
The internal APIM endpoint `apim-daids-connect.azure-api.net` does not resolve from within the VNet.

**Error:**
```
DNS lookup: NXDOMAIN (server can't find apim-daids-connect.azure-api.net)
Curl: Could not resolve host
```

**Root Cause:**
No Azure Private DNS Zone configured for the internal APIM endpoint.

**Resolution Required:**
1. Create an Azure Private DNS Zone for the APIM domain
2. Link the private DNS zone to the VNet `nih-niaid-azurestrides-dev-apim-az`
3. Add an A record pointing `apim-daids-connect.azure-api.net` to the APIM's private IP
4. Or configure custom DNS servers that can resolve the internal hostname

**Workaround:**
Use the APIM's private IP address directly if available (requires querying Azure resources).

## Troubleshooting

### View Workflow Runs
```bash
# List recent runs
gh run list --workflow=test-apis.yaml --limit 5

# View specific run
gh run view <run-id>

# View failed logs
gh run view <run-id> --log-failed
```

### Watch Live Execution
```bash
gh run watch
```

### Test Specific Scenarios
```bash
# Single API test
gh workflow run test-apis.yaml -f ENVIRONMENT=prod -f TEST_TYPE=endpoint-availability -f API_NAME=echo-api

# All APIs health check
gh workflow run test-apis.yaml -f ENVIRONMENT=prod -f TEST_TYPE=health-check
```

## Future Enhancements

When production APIM moves to internal VNet:
1. Update `test-apis-ephemeral.yaml` lines 63-65 with prod VNet/subnet details
2. Configure prod Private DNS Zone
3. Switch prod testing to use ephemeral VM workflow

## Related Workflows

- [run-extractor.yaml](.github/workflows/run-extractor.yaml) - Extracts APIM artifacts
- [run-publisher.yaml](.github/workflows/run-publisher.yaml) - Publishes artifacts to environments
