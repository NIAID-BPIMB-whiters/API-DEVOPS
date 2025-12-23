# Production APIM VNet Migration Plan

## Executive Summary

**Objective**: Migrate production APIM instance (`niaid-bpimb-apim-dev`) from External/Public mode to Internal VNet mode to match dev environment security posture.

**Timeline**: 4-6 hours (including preparation, execution, and validation)

**Downtime**: 30-45 minutes during VNet integration

**Environment**: NIH.NIAID.AzureSTRIDES_Dev subscription

---

## Current State

### Production APIM (niaid-bpimb-apim-dev)
- **Resource Group**: niaid-bpimb-apim-dev-rg
- **Location**: eastus2
- **SKU**: Developer
- **Network Type**: External (publicly accessible)
- **Gateway URL**: https://niaid-bpimb-apim-dev.azure-api.net
- **VNet**: None
- **APIs**: 8 (crms-api-qa, demo-conference-api, echo-api, itpms-chat-api, merlin-db, opentext, otcs-mcp-server, test)

### Development APIM (apim-daids-connect) - Target State Reference
- **Network Type**: Internal VNet
- **VNet**: nih-niaid-azurestrides-dev-apim-az (10.178.57.0/24)
- **Subnet**: niaid-apim (10.178.57.48/28)
- **Private IP**: 10.178.57.52
- **Testing Method**: Ephemeral Azure VMs

---

## Migration Phases

### Phase 1: Pre-Migration Planning (1-2 hours)

#### 1.1 Dependency Assessment
- [ ] Identify all systems/applications consuming prod APIM APIs
- [ ] Document external vs internal consumers
- [ ] Notify stakeholders of planned migration and downtime window
- [ ] Verify backup/disaster recovery procedures

#### 1.2 Access Verification
```powershell
# Verify your Owner role on subscription
az role assignment list --assignee (az ad signed-in-user show --query id -o tsv) --scope /subscriptions/18fc6b8b-44fa-47d7-ae51-36766ac67165
```

**Status**: ✅ Confirmed - whiters@nih.gov has Owner role

#### 1.3 Network Planning

**VNet Address Space**: 10.179.0.0/24 (avoid conflict with dev 10.178.57.0/24)

**Subnet Plan**:
| Subnet Name | Address Prefix | Purpose |
|-------------|----------------|---------|
| prod-apim-subnet | 10.179.0.0/28 | APIM instance (16 IPs) |
| prod-commonservices | 10.179.0.32/27 | Test VMs and other services (32 IPs) |
| prod-appgw-subnet | 10.179.0.64/27 | Future Application Gateway (32 IPs) |

---

### Phase 2: Infrastructure Preparation (1-2 hours)

#### 2.1 Create VNet Resource Group (Optional)

**Decision**: Use existing `niaid-bpimb-apim-dev-rg` or create separate `niaid-bpimb-apim-prod-network-rg`

**Recommendation**: Separate RG for network resources (following dev pattern)

```powershell
# Create network resource group
az group create \
  --name niaid-bpimb-apim-prod-network-rg \
  --location eastus2 \
  --tags Environment=Production Component=Network ManagedBy=APIDevOps
```

#### 2.2 Create Virtual Network

```powershell
# Create VNet
az network vnet create \
  --name niaid-bpimb-apim-prod-vnet \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --location eastus2 \
  --address-prefix 10.179.0.0/24 \
  --tags Environment=Production Component=Network

# Create APIM subnet
az network vnet subnet create \
  --name prod-apim-subnet \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --vnet-name niaid-bpimb-apim-prod-vnet \
  --address-prefix 10.179.0.0/28

# Create test VM subnet
az network vnet subnet create \
  --name prod-commonservices \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --vnet-name niaid-bpimb-apim-prod-vnet \
  --address-prefix 10.179.0.32/27
```

#### 2.3 Configure Network Security Group

```powershell
# Create NSG
az network nsg create \
  --name prod-apim-nsg \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --location eastus2 \
  --tags Environment=Production Component=Security

# Required APIM management traffic (port 3443)
az network nsg rule create \
  --name AllowAPIMManagement \
  --nsg-name prod-apim-nsg \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes ApiManagement \
  --source-port-ranges '*' \
  --destination-address-prefixes VirtualNetwork \
  --destination-port-ranges 3443 \
  --description "APIM management endpoint"

# HTTPS traffic for API gateway (port 443)
az network nsg rule create \
  --name AllowHTTPS \
  --nsg-name prod-apim-nsg \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --priority 110 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes VirtualNetwork \
  --source-port-ranges '*' \
  --destination-address-prefixes VirtualNetwork \
  --destination-port-ranges 443 \
  --description "HTTPS API traffic"

# Azure Load Balancer (required for APIM)
az network nsg rule create \
  --name AllowAzureLoadBalancer \
  --nsg-name prod-apim-nsg \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --priority 120 \
  --direction Inbound \
  --access Allow \
  --protocol '*' \
  --source-address-prefixes AzureLoadBalancer \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges '*' \
  --description "Azure Load Balancer probes"

# Outbound rule for dependency services
az network nsg rule create \
  --name AllowOutboundAPIMDependencies \
  --nsg-name prod-apim-nsg \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --priority 100 \
  --direction Outbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes VirtualNetwork \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 443 1433 \
  --description "APIM dependencies (SQL, Storage)"

# Associate NSG with APIM subnet
az network vnet subnet update \
  --name prod-apim-subnet \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --vnet-name niaid-bpimb-apim-prod-vnet \
  --network-security-group prod-apim-nsg
```

#### 2.4 Validation Checkpoint

```powershell
# Verify VNet creation
az network vnet show \
  --name niaid-bpimb-apim-prod-vnet \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --query "{name:name,addressSpace:addressSpace.addressPrefixes,subnets:subnets[].name}"

# Verify NSG rules
az network nsg rule list \
  --nsg-name prod-apim-nsg \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --query "[].{Name:name,Priority:priority,Direction:direction,Access:access}" \
  --output table
```

---

### Phase 3: APIM VNet Integration (30-45 minutes downtime)

#### 3.1 Pre-Migration Backup

```powershell
# Take configuration snapshot before migration
az apim show \
  --name niaid-bpimb-apim-dev \
  --resource-group niaid-bpimb-apim-dev-rg \
  > apim-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json

# Run extractor to backup all configurations
gh workflow run run-extractor.yaml \
  -f CONFIGURATION_YAML_PATH=configuration.extractor.yaml \
  -f API_SPECIFICATION_FORMAT=OpenAPIV3Yaml
```

#### 3.2 Execute VNet Integration

**⚠️ CRITICAL: This step causes 30-45 minute downtime**

```powershell
# Get subnet resource ID
$subnetId = az network vnet subnet show \
  --name prod-apim-subnet \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --vnet-name niaid-bpimb-apim-prod-vnet \
  --query id -o tsv

# Update APIM to Internal VNet mode
az apim update \
  --name niaid-bpimb-apim-dev \
  --resource-group niaid-bpimb-apim-dev-rg \
  --virtual-network Internal \
  --virtual-network-configuration subnetResourceId=$subnetId
```

**Expected Output**: Operation will show "Running" status. Monitor progress:

```powershell
# Monitor the update operation
az apim show \
  --name niaid-bpimb-apim-dev \
  --resource-group niaid-bpimb-apim-dev-rg \
  --query "{name:name,provisioningState:provisioningState,virtualNetworkType:virtualNetworkType}"
```

Wait until `provisioningState` returns `Succeeded`.

#### 3.3 Retrieve Private IP

```powershell
# Get assigned private IP address
$privateIP = az resource show \
  --ids "/subscriptions/18fc6b8b-44fa-47d7-ae51-36766ac67165/resourceGroups/niaid-bpimb-apim-dev-rg/providers/Microsoft.ApiManagement/service/niaid-bpimb-apim-dev" \
  --query "properties.privateIPAddresses[0]" -o tsv

Write-Host "APIM Private IP: $privateIP"
```

**Document this IP** - you'll need it for DNS and testing.

---

### Phase 4: DNS Configuration (15-30 minutes)

#### 4.1 Create Private DNS Zone

```powershell
# Create Private DNS Zone for azure-api.net
az network private-dns zone create \
  --name azure-api.net \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --tags Environment=Production Component=DNS

# Link DNS zone to VNet
az network private-dns link vnet create \
  --name prod-apim-vnet-link \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --zone-name azure-api.net \
  --virtual-network niaid-bpimb-apim-prod-vnet \
  --registration-enabled false
```

#### 4.2 Create DNS A Record

```powershell
# Create A record for APIM gateway (use private IP from step 3.3)
az network private-dns record-set a add-record \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --zone-name azure-api.net \
  --record-set-name niaid-bpimb-apim-dev \
  --ipv4-address $privateIP

# Verify DNS record
az network private-dns record-set a show \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --zone-name azure-api.net \
  --name niaid-bpimb-apim-dev
```

#### 4.3 Create Regional Endpoint Record (if needed)

```powershell
# If regional endpoint is used
az network private-dns record-set a add-record \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --zone-name regional.azure-api.net \
  --record-set-name niaid-bpimb-apim-dev-eastus2-01 \
  --ipv4-address $privateIP
```

---

### Phase 5: Service Principal Permissions (5-10 minutes)

```powershell
# Grant GitHub service principal access to network resource group
az role assignment create \
  --assignee a763a856-d2ae-43ab-b686-0cf24a5da690 \
  --role "Contributor" \
  --scope /subscriptions/18fc6b8b-44fa-47d7-ae51-36766ac67165/resourceGroups/niaid-bpimb-apim-prod-network-rg

# Verify permission
az role assignment list \
  --assignee a763a856-d2ae-43ab-b686-0cf24a5da690 \
  --scope /subscriptions/18fc6b8b-44fa-47d7-ae51-36766ac67165/resourceGroups/niaid-bpimb-apim-prod-network-rg \
  --output table
```

---

### Phase 6: Update GitHub Workflows (10-15 minutes)

#### 6.1 Update test-apis-ephemeral.yaml

Update the prod environment section with VNet details:

```yaml
# In .github/workflows/test-apis-ephemeral.yaml, lines ~63-69
if [ "${{ github.event.inputs.ENVIRONMENT }}" == "prod" ]; then
  RG="niaid-bpimb-apim-dev-rg"
  VNET_RG="niaid-bpimb-apim-prod-network-rg"
  VNET="niaid-bpimb-apim-prod-vnet"
  SUBNET="prod-commonservices"
  # Use private IP for prod (internal VNet)
  APIM_GATEWAY="<PRIVATE_IP_FROM_STEP_3.3>"
  APIM_HOST="niaid-bpimb-apim-dev.azure-api.net"
```

#### 6.2 Update test-apis.yaml

Add comment noting that this workflow is now for local/VPN testing only:

```yaml
# NOTE: This workflow now requires VPN or internal network access for prod
# For automated testing, use test-apis-ephemeral.yaml which creates VMs in the VNet
```

#### 6.3 Commit and Push Changes

```powershell
cd C:\Users\whiters\github-niaud\apidevops\API-DEVOPS
git add .github/workflows/test-apis-ephemeral.yaml
git add .github/workflows/test-apis.yaml
git commit -m "Update workflows for prod internal VNet configuration"
git push
```

---

### Phase 7: Testing & Validation (30-60 minutes)

#### 7.1 Test from Ephemeral VM

```powershell
# Run ephemeral VM test for prod
gh workflow run test-apis-ephemeral.yaml \
  -f ENVIRONMENT=prod \
  -f TEST_TYPE=health-check

# Monitor the run
gh run watch
```

**Expected Result**: ✅ Gateway health check passed (HTTP 404)

#### 7.2 Test All APIs

```powershell
# Test all endpoints
gh workflow run test-apis-ephemeral.yaml \
  -f ENVIRONMENT=prod \
  -f TEST_TYPE=full-suite

# Monitor execution
gh run watch
```

**Expected Result**: All 8 APIs return HTTP 404 (reachable)

#### 7.3 Test Individual APIs

```powershell
# Test specific APIs
gh workflow run test-apis-ephemeral.yaml \
  -f ENVIRONMENT=prod \
  -f TEST_TYPE=endpoint-availability \
  -f API_NAME=echo-api
```

#### 7.4 Verify DNS Resolution from VNet

Deploy a test VM to verify DNS:

```powershell
# Create test VM in prod VNet
az vm create \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --name prod-test-vm \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --subnet prod-commonservices \
  --vnet-name niaid-bpimb-apim-prod-vnet \
  --public-ip-address "" \
  --nsg ""

# Test DNS resolution via run-command
az vm run-command invoke \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --name prod-test-vm \
  --command-id RunShellScript \
  --scripts "nslookup niaid-bpimb-apim-dev.azure-api.net; curl -k https://niaid-bpimb-apim-dev.azure-api.net"

# Cleanup test VM
az vm delete \
  --resource-group niaid-bpimb-apim-prod-network-rg \
  --name prod-test-vm \
  --yes --no-wait
```

#### 7.5 Validation Checklist

- [ ] APIM shows `virtualNetworkType: Internal`
- [ ] Private IP assigned in 10.179.0.0/28 range
- [ ] DNS resolution works from within VNet
- [ ] Ephemeral VM tests pass for prod
- [ ] All 8 APIs accessible via private IP
- [ ] External access blocked (expected behavior)
- [ ] GitHub workflows execute successfully

---

### Phase 8: Documentation Updates

#### 8.1 Update TESTING.md

Document the new prod configuration:

```markdown
### Production Environment
- **APIM Gateway**: `niaid-bpimb-apim-dev.azure-api.net` (private IP: `<IP>`)
- **Network Type**: Internal VNet
- **VNet**: `niaid-bpimb-apim-prod-vnet`
- **Subnet**: `prod-apim-subnet`
- **Testing Method**: Ephemeral Azure VMs with private IP
- **Status**: ✅ Fully operational
- **Migration Date**: [COMPLETION_DATE]
```

#### 8.2 Update README (if exists)

Add migration notes and access requirements.

---

## Rollback Plan

### If Issues Occur During Migration

**Within 2 hours of starting VNet integration:**

```powershell
# Cancel in-progress operation (if possible)
# Note: VNet integration cannot be easily cancelled once started

# If migration completes but issues arise:
# Revert to External mode
az apim update \
  --name niaid-bpimb-apim-dev \
  --resource-group niaid-bpimb-apim-dev-rg \
  --virtual-network None
```

**⚠️ WARNING**: Reverting also takes 30-45 minutes and causes additional downtime.

### Post-Rollback Actions

1. Verify external access restored
2. Test APIs from GitHub-hosted runners
3. Notify stakeholders
4. Investigate root cause
5. Schedule retry with fixes

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Extended downtime (>45 min) | Low | High | Have Azure support contact ready |
| DNS resolution issues | Medium | High | Test thoroughly in Phase 7 before stakeholder notification |
| Service principal permission issues | Low | Medium | Pre-validated in Phase 5 |
| Application connectivity loss | Medium | High | Comprehensive dependency assessment in Phase 1.1 |
| Rollback needed | Low | High | Document all configurations before migration |

---

## Communication Plan

### Stakeholder Notifications

**Before Migration (24-48 hours notice):**
- Email to all APIM consumers
- Include: downtime window, expected duration, impact, rollback plan

**During Migration:**
- Status updates every 15 minutes during downtime
- Immediate notification if issues arise

**After Migration:**
- Success notification
- Updated access instructions (VPN/network requirements)
- New testing procedures

---

## Post-Migration Monitoring

### First 24 Hours

- [ ] Monitor APIM health metrics in Azure Portal
- [ ] Check for any failed API calls
- [ ] Verify GitHub workflow execution history
- [ ] Monitor Azure costs for unexpected changes
- [ ] Collect feedback from API consumers

### First Week

- [ ] Daily health checks via ephemeral VM tests
- [ ] Review application logs for connectivity issues
- [ ] Document any unexpected behaviors
- [ ] Update network diagrams

---

## Resources & References

### Azure Documentation
- [APIM Virtual Network Configuration](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet)
- [Internal VNet Mode](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet)
- [NSG Rules for APIM](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet#network-configuration-issues)

### Current Environment Details
- Dev APIM: apim-daids-connect (Internal VNet) ✅
- Prod APIM: niaid-bpimb-apim-dev (External → to be migrated)
- Subscription: NIH.NIAID.AzureSTRIDES_Dev
- Your Role: Owner ✅

### Contact Information
- Azure Support: [Support Portal](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)
- Network Admin: [TBD]
- Stakeholder Lead: [TBD]

---

## Approval & Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Technical Lead | whiters@nih.gov | | |
| Network Admin | | | |
| Security Admin | | | |
| Business Owner | | | |

---

## Execution Log

| Phase | Start Time | End Time | Status | Notes |
|-------|------------|----------|--------|-------|
| Phase 1: Planning | | | | |
| Phase 2: Infrastructure | | | | |
| Phase 3: VNet Integration | | | | |
| Phase 4: DNS Configuration | | | | |
| Phase 5: Permissions | | | | |
| Phase 6: Workflow Updates | | | | |
| Phase 7: Testing | | | | |
| Phase 8: Documentation | | | | |

---

**Migration Plan Version**: 1.0  
**Created**: December 23, 2025  
**Created By**: whiters@nih.gov  
**Last Updated**: December 23, 2025
