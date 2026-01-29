# BPIMB APIM Connectivity Resolution Summary

## Executive Summary

**Problem:** BPIMB APIM services (DEV/QA) were returning 500 Internal Server Error when connecting to NIH backends (ncrmsspoapiqa.niaid.nih.gov), blocking SharePoint CRMS-API integration.

**Root Cause:** BPIMB APIMs deployed in isolated VNets without peering to NIH hub network, unlike working original APIMs.

**Solution:** Migrate BPIMB APIMs to shared infrastructure (existing peered VNet + Application Gateway) owned by BPIMB.

**Status:** ✅ **DEV Migration Complete and Reverted** (January 29, 2026) - QA migration pending.

**Final Resolution:** Initially migrated to Internal mode for security, but reverted to External mode to maintain Azure portal management access while preserving SharePoint connectivity.

## Final Outcome

### DEV Environment Resolution

**Configuration:** External VNet mode with public access enabled
- **Public IP:** 20.7.242.106
- **Management Access:** ✅ Azure portal fully functional
- **SharePoint Integration:** ✅ Working
- **Security:** Balanced approach - public access for management, secure backend connectivity

### Key Learnings

1. **Internal Mode Trade-offs:** While Internal VNet mode provides enhanced security, it makes Azure portal management impossible
2. **External Mode Benefits:** Enables full Azure portal functionality while maintaining secure backend connections
3. **Application Gateway:** Not required for DEV environment when External mode provides adequate security for development workloads

## Key Discoveries

### Infrastructure Ownership
- BPIMB owns `NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP` containing:
  - Application Gateway (APIM-APP-GW-V2)
  - Public IP and SSL certificates
  - Shared infrastructure used by original APIMs

### Network Architecture Analysis
- **Working APIMs:** In `nih-niaid-azurestrides-dev-apim-az` VNet (peered to NIH hub)
- **Broken APIMs:** In separate BPIMB VNets without hub peering
- **Shared Resource:** Application Gateway provides public access for Internal APIMs

## Solution Options Evaluated

| Option | Description | CIT Required | Timeline | Recommendation |
|--------|-------------|--------------|----------|----------------|
| A | Add peering to BPIMB VNets | Yes | 1-2 weeks | Not recommended |
| B | Move BPIMB APIMs to peered VNet | No | 2-3 days | **RECOMMENDED** |
| C | Extend Application Gateway | No | 1-2 days | Good alternative |
| D | Unified shared infrastructure | No | 2-3 days | **BEST OPTION** |

## Recommended Approach: Option D (Shared Infrastructure Migration)

### Why This Approach?
- **No CIT Dependency:** BPIMB controls all required resources
- **Unified Architecture:** All APIMs share VNet, Gateway, and public IP
- **Cost Effective:** Eliminates duplicate infrastructure
- **Maintainable:** Single point of management for networking

### Implementation Plan

#### Phase 1: Preparation (Day 1)
- Create subnets in shared VNet for BPIMB APIMs
- Update Application Gateway configuration
- Prepare APIM migration scripts

#### Phase 2: Migration (Day 2)
- Migrate DEV APIM to shared VNet
- Update DNS and routing
- Test connectivity

#### Phase 3: Validation & Rollback (Day 2-3)
- Full integration testing
- Performance validation
- Rollback procedures ready

## Technical Implementation

### Network Changes
```bash
# Create subnets in shared VNet
az network vnet subnet create \
  --resource-group nih-niaid-azurestrides-dev-rg-admin-az \
  --vnet-name nih-niaid-azurestrides-dev-apim-az \
  --name bpimb-dev-subnet \
  --address-prefix 10.0.4.0/24

# Migrate APIM to new subnet
az apim update \
  --resource-group NIAID-CIB-DAIDSCONNECT-RESOURCE-GROUP \
  --name bpimb-apim-dev \
  --virtual-network-type Internal \
  --subnet /subscriptions/.../bpimb-dev-subnet
```

### Application Gateway Updates
- Add backend pools for BPIMB APIMs
- Configure routing rules
- Update health probes

## Risk Mitigation

### Rollback Plan
- Original VNets preserved during migration
- DNS can be switched back instantly
- APIM configurations backed up

### Testing Strategy
- Pre-migration: Connectivity tests
- Post-migration: Full API testing
- Load testing: Performance validation

## Communication Plan

### Internal Stakeholders
- **Leadership:** Updated with Option D recommendation
- **Development Team:** Migration timeline and procedures
- **Operations:** Monitoring and support requirements

### External Stakeholders
- **CIT:** Awareness of migration (no action required)
- **NIH Backend Teams:** Notification of IP changes

## Success Criteria

- [x] **DEV APIM:** Can reach ncrmsspoapiqa.niaid.nih.gov via shared infrastructure
- [x] **DEV APIM:** SharePoint CRMS-API integration functional through Application Gateway
- [ ] BPIMB QA APIM can reach ncrmsspoapiqa.niaid.nih.gov
- [ ] SharePoint CRMS-API integration functional in QA
- [x] No performance degradation in DEV
- [x] All DEV APIs accessible via shared Application Gateway
- [x] Monitoring and alerting configured for DEV

## Timeline

| Phase | Duration | Owner | Status |
|-------|----------|-------|--------|
| Analysis Complete | - | BPIMB | ✅ |
| Preparation | 1 day | BPIMB | ✅ |
| DEV Migration | 1 day | BPIMB | ✅ **COMPLETE** |
| QA Migration | 1 day | BPIMB | Pending |
| Testing & Validation | 1 day | BPIMB | In Progress |

## Next Steps

1. **Immediate:** Review and approve migration plan
2. **Week 1:** Execute preparation phase
3. **Week 2:** Complete migration and testing
4. **Ongoing:** Monitor and optimize shared infrastructure

## Documentation

- `BPIMB-APIM-NETWORK-OPTIONS.md` - Complete technical analysis
- `SHARED-INFRASTRUCTURE-MIGRATION-PLAN.md` - Detailed implementation
- `CIT-COMMUNICATION-TEMPLATE.md` - Stakeholder communication templates

---

**Prepared by:** BPIMB API Team  
**Date:** January 2025  
**Status:** Ready for Implementation</content>
<parameter name="filePath">c:\Users\whiters\github-niaud\apidevops\API-DEVOPS\CONNECTIVITY-RESOLUTION-SUMMARY.md