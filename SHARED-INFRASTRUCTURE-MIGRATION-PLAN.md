# BPIMB APIM Shared Infrastructure Migration Plan

**Date**: January 28, 2026
**Objective**: Migrate BPIMB APIMs to shared infrastructure with original APIMs
**Approach**: Option D - Shared VNet, Gateway, and Public IP
**Timeline**: 2-3 days
**Risk Level**: Medium

---

## Executive Summary

**Current State:**
- ✅ BPIMB DEV APIM migrated to shared infrastructure (completed Jan 29, 2026)
- BPIMB QA APIM in separate VNet (migration pending)
- Original APIMs in shared peered VNet + shared Application Gateway

**Target State:**
- All APIMs (original + BPIMB) in shared `nih-niaid-azurestrides-dev-vnet-apim-az` VNet
- All APIMs using shared `APIM-APP-GW-V2` Application Gateway
- All APIMs in Internal VNet mode for security
- Unified backend connectivity via existing VNet peering

**Benefits:**
- ✅ No CIT involvement required
- ✅ Unified infrastructure management
- ✅ Cost effective (no new resources)
- ✅ Full BPIMB control over all components

---

## ✅ COMPLETED: DEV APIM Migration (January 29, 2026)

### Migration Results
- ✅ **APIM Status**: `Succeeded` (Internal mode)
- ✅ **Private IP**: `10.178.57.196`
- ✅ **VNet**: Connected to `nih-niaid-azurestrides-dev-vnet-apim-az`
- ✅ **Application Gateway**: Added to `APIM-APP-GW-V2` backend pool
- ✅ **Health Checks**: Passing (200 status codes)
- ✅ **Routing**: Traffic flows correctly through Gateway

### Infrastructure Changes Made
1. **Network Setup**: Created `bpimb-apim-dev` subnet (10.178.57.192/27)
2. **NSG Configuration**: Applied matching rules from working APIM
3. **Service Endpoints**: Enabled Key Vault, Storage, Container Registry, etc.
4. **Gateway Integration**: Backend pool, health probes, routing rules configured
5. **Access Control**: Set to internal-only via private IP (10.178.57.9)

### Testing Completed
- ✅ Application Gateway health checks
- ✅ Traffic routing verification
- ✅ APIM response validation
- ✅ Network connectivity to NIH backends

### Next Steps
- **QA Migration**: Apply same process to `niaid-bpimb-apim-qa`
- **Testing**: Validate SharePoint CRMS-API connectivity in DEV
- **Documentation**: Update all docs with network changes (completed)

---

## Pre-Migration Preparation

### 1. Environment Assessment
- [ ] Verify BPIMB owns `NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP`
- [ ] Confirm existing VNet peering status
- [ ] Document current APIM configurations
- [ ] Backup all APIM artifacts and configurations

### 2. Resource Planning
**New Subnets Needed:**
- `bpimb-dev-subnet`: 10.178.57.112/28 (16 IPs)
- `bpimb-qa-subnet`: 10.178.57.128/28 (16 IPs)

**Application Gateway Updates:**
- Add BPIMB APIMs to existing backend pool
- Configure hostname-based routing (if needed)
- SSL certificate management

### 3. Schedule Maintenance Window
- [ ] QA migration: Schedule low-impact window
- [ ] DEV migration: Schedule SharePoint off-hours
- [ ] Notify stakeholders of potential downtime
- [ ] Prepare rollback procedures

---

## Phase 1: Infrastructure Preparation (Day 1)

### 1.1 Create VNet Subnets
```bash
# Create subnet for BPIMB DEV APIM
az network vnet subnet create \
  --resource-group nih-niaid-azurestrides-dev-rg-admin-az \
  --vnet-name nih-niaid-azurestrides-dev-apim-az \
  --name bpimb-dev-subnet \
  --address-prefix 10.178.57.112/28

# Create subnet for BPIMB QA APIM
az network vnet subnet create \
  --resource-group nih-niaid-azurestrides-dev-rg-admin-az \
  --vnet-name nih-niaid-azurestrides-dev-apim-az \
  --name bpimb-qa-subnet \
  --address-prefix 10.178.57.128/28
```

### 1.2 Verify VNet Peering
```bash
# Confirm peering to NIH hub is active
az network vnet peering list \
  --resource-group nih-niaid-azurestrides-dev-rg-admin-az \
  --vnet-name nih-niaid-azurestrides-dev-apim-az \
  --query "[].{Name:name, State:peeringState, RemoteVNet:remoteVirtualNetwork.id}" \
  --output table
```

### 1.3 Prepare Application Gateway Updates
```bash
# Backup current Application Gateway configuration
az network application-gateway show \
  --resource-group NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP \
  --name APIM-APP-GW-V2 \
  --output json > gateway-backup.json
```

---

## Phase 2: QA APIM Migration (Day 1-2)

### 2.1 Pre-Migration Testing
- [ ] Run full API test suite on QA
- [ ] Verify SharePoint connectivity to QA APIs
- [ ] Document current response times and error rates

### 2.2 APIM Migration
**⚠️ DOWNTIME: ~3-5 minutes**

```bash
# Note: APIM VNet migration requires recreation or reconfiguration
# This may involve temporary downtime

# Option 1: If using ARM templates (recommended)
# Update ARM template with new VNet/subnet
# Redeploy APIM with new network configuration

# Option 2: If using portal/APIM REST API
# Update APIM virtual network settings
# Change from current VNet to nih-niaid-azurestrides-dev-apim-az/bpimb-qa-subnet
# Change VNet type to Internal
```

### 2.3 Update Application Gateway
```bash
# Add QA APIM to existing backend pool
az network application-gateway address-pool update \
  --resource-group NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP \
  --gateway-name APIM-APP-GW-V2 \
  --name apim-backend \
  --servers niaid-bpimb-apim-qa.azure-api.net

# If hostname routing needed:
az network application-gateway http-listener create \
  --resource-group NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP \
  --gateway-name APIM-APP-GW-V2 \
  --name qa-listener \
  --frontend-ip appGwPrivateFrontendIpIPv4 \
  --frontend-port port_80 \
  --host-names "*.bpimb-qa.niaid.nih.gov"
```

### 2.4 Post-Migration Testing
- [ ] Verify APIM is accessible via Application Gateway
- [ ] Test backend connectivity to `ncrmsspoapiqa.niaid.nih.gov`
- [ ] Run API test suite
- [ ] Verify SharePoint integration

### 2.5 Rollback Plan (If Issues)
```bash
# Revert Application Gateway changes
az network application-gateway address-pool update \
  --resource-group NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP \
  --gateway-name APIM-APP-GW-V2 \
  --name apim-backend \
  --servers <original-servers-only>

# Migrate APIM back to original VNet/subnet
# (Reverse of migration steps)
```

---

## Phase 3: DEV APIM Migration (Day 2-3)

### 3.1 Pre-Migration Preparation
- [ ] Schedule SharePoint maintenance window
- [ ] Notify SharePoint users of potential downtime
- [ ] Run full API test suite on DEV
- [ ] Document current configurations

### 3.2 APIM Migration
**⚠️ DOWNTIME: ~3-5 minutes + SharePoint reconfiguration**

```bash
# Migrate DEV APIM to shared VNet
# Change VNet type from External to Internal
# Update subnet to bpimb-dev-subnet

# This will break SharePoint connectivity temporarily
```

### 3.3 Update Application Gateway
```bash
# Add DEV APIM to backend pool
az network application-gateway address-pool update \
  --resource-group NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP \
  --gateway-name APIM-APP-GW-V2 \
  --name apim-backend \
  --servers niaid-bpimb-apim-dev.azure-api.net

# Configure hostname routing if needed
az network application-gateway http-listener create \
  --resource-group NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP \
  --gateway-name APIM-APP-GW-V2 \
  --name dev-listener \
  --frontend-ip appGwPrivateFrontendIpIPv4 \
  --frontend-port port_80 \
  --host-names "*.bpimb-dev.niaid.nih.gov"
```

### 3.4 SharePoint Reconfiguration
- [ ] Update SharePoint connection strings to use Application Gateway URL
- [ ] Test SharePoint → APIM connectivity
- [ ] Verify all integrations work

### 3.5 Full System Testing
- [ ] End-to-end testing: SharePoint → APIM → Backend
- [ ] Performance testing
- [ ] Load testing
- [ ] Security testing

---

## Phase 4: Custom Domains & SSL (Optional)

### 4.1 Add Custom Domains
```bash
# Add custom domains for cleaner URLs (optional)
az apim custom-domain create \
  --resource-group niaid-bpimb-apim-dev-rg \
  --service-name niaid-bpimb-apim-dev \
  --custom-domain proxy \
  --domain-name gateway.bpimb-dev.niaid.nih.gov

az apim custom-domain create \
  --resource-group niaid-bpimb-apim-qa-rg \
  --service-name niaid-bpimb-apim-qa \
  --custom-domain proxy \
  --domain-name gateway.bpimb-qa.niaid.nih.gov
```

### 4.2 SSL Certificate Management
- [ ] Obtain SSL certificates for custom domains
- [ ] Configure Application Gateway SSL termination
- [ ] Update DNS records

---

## Monitoring & Validation

### Success Criteria
- [ ] All APIMs accessible via Application Gateway
- [ ] Backend connectivity to NIH services working
- [ ] SharePoint integration functional
- [ ] API test suites passing
- [ ] No performance degradation

### Monitoring Setup
- [ ] Configure Application Gateway metrics
- [ ] Set up APIM monitoring and alerts
- [ ] Monitor VNet peering status
- [ ] Track API response times

---

## Risk Mitigation

### High-Risk Items
1. **APIM Migration Downtime**: Schedule during low-usage periods
2. **SharePoint Impact**: Have rollback plan ready
3. **Application Gateway Changes**: Test in staging first

### Contingency Plans
- **Immediate Rollback**: Revert to original configurations
- **Partial Rollback**: Keep QA migrated, rollback DEV only
- **Alternative Access**: Direct APIM access during issues

---

## Timeline & Responsibilities

### Day 1: Infrastructure & QA Migration
- **Infrastructure Team**: Create subnets, verify peering
- **DevOps Team**: Migrate QA APIM, update Application Gateway
- **QA Team**: Test QA functionality

### Day 2: DEV Migration
- **Infrastructure Team**: Schedule maintenance window
- **DevOps Team**: Migrate DEV APIM
- **SharePoint Team**: Update configurations

### Day 3: Testing & Validation
- **All Teams**: End-to-end testing
- **DevOps Team**: Monitoring setup
- **Business Team**: User acceptance testing

---

## Success Metrics

- ✅ **Zero downtime** beyond scheduled maintenance
- ✅ **All APIs functional** via Application Gateway
- ✅ **SharePoint integration working**
- ✅ **Backend connectivity established**
- ✅ **Performance maintained** (response times < 500ms)
- ✅ **Security compliance** (all Internal mode)

---

## Post-Migration Tasks

- [ ] Update documentation with new architecture
- [ ] Train teams on shared infrastructure
- [ ] Establish monitoring baselines
- [ ] Plan for future scaling
- [ ] Review cost optimization opportunities

---

**Approval Required**: Leadership approval for migration execution
**Go/No-Go Decision**: Based on QA migration success
**Rollback Window**: 24 hours post-migration
**Support**: 24/7 monitoring during transition</content>
<parameter name="filePath">c:\Users\whiters\github-niaud\apidevops\API-DEVOPS\SHARED-INFRASTRUCTURE-MIGRATION-PLAN.md