# Major Architecture Changes - January 2026

**Date**: January 13, 2026  
**Status**: Planning Phase  

## Overview

Major infrastructure expansion to support sandbox development, production deployment, and improved workflow architecture.

---

## 🎯 Initiative 1: Create Sandbox Environment

### Objective
Create `niaid-bpimb-apim-sb` as a sandbox environment mirroring DEV architecture for POC work with promotion path to DEV.

### Resources to Create

#### Azure Resources
- **Resource Group**: `niaid-bpimb-apim-sb-rg`
- **APIM Service**: `niaid-bpimb-apim-sb`
- **Subscription**: NIH.NIAID.AzureSTRIDES (same as DEV/QA)
- **Location**: Same as DEV (likely East US)
- **Tier**: Developer or Basic (for cost optimization)

#### Networking
- [ ] VLAN/VNet configuration
  - Option A: Create new subnet in existing `nih-niaid-azurestrides-dev-vnet-apim-az`
  - Option B: Create dedicated VNet (if isolation required)
  - **Recommendation**: Use existing VNet with new subnet to mirror DEV architecture
- [ ] Private IP address allocation
- [ ] Network security group rules
- [ ] DNS configuration
- [ ] Internal gateway URL: `niaid-bpimb-apim-sb.azure-api.net`

#### Service Principal
- [ ] Create Azure AD App Registration: `apiops-sb-sp`
- [ ] Create client secret (store in Key Vault)
- [ ] Assign RBAC permissions:
  - `API Management Service Contributor` on `niaid-bpimb-apim-sb`
  - `Reader` on `niaid-bpimb-apim-sb-rg`
  - `Key Vault Secrets User` on shared Key Vault (if applicable)
- [ ] Document credentials in secure location

#### GitHub Secrets/Environments
- [ ] Create GitHub environment: `apim-bpimb-sb`
- [ ] Add secrets to `apim-bpimb-sb` environment:
  - `AZURE_CLIENT_ID` (from SP)
  - `AZURE_CLIENT_SECRET` (from SP)
  - `AZURE_TENANT_ID` (same as DEV/QA)
  - `AZURE_SUBSCRIPTION_ID` (same as DEV/QA)
  - `AZURE_RESOURCE_GROUP_NAME` = `niaid-bpimb-apim-sb-rg`
  - `API_MANAGEMENT_SERVICE_NAME` = `niaid-bpimb-apim-sb`
  - `APIM_SUBSCRIPTION_KEY` (for testing)
- [ ] Create approval environment: `approve-apim-bpimb-sb`
- [ ] Configure required reviewers for sandbox approval

#### Configuration Files
- [ ] Create `configuration.sandbox.yaml` (copy from `configuration.dev.yaml`)
- [ ] Update environment-specific settings:
  - Service name: `niaid-bpimb-apim-sb`
  - Resource group: `niaid-bpimb-apim-sb-rg`
  - Gateway URL mappings
  - Backend service URLs (if different from DEV)
  - Named values / environment variables

#### Workflow Updates
- [ ] Update `run-publisher.yaml` to support sandbox environment
  - Add sandbox deployment job
  - Add approval gate for sandbox
  - Add test job for sandbox
  - Add cleanup job for sandbox
  - Add tagging job: `deploy-sb-{timestamp}-{sha}`
- [ ] Update `rollback-deployment.yaml` to support sandbox
- [ ] Update `cleanup-orphaned-apis.yaml` to support sandbox
- [ ] Update `test-apis-ephemeral.yaml` to test sandbox APIs

#### Documentation
- [ ] Update README.md environments table
- [ ] Document sandbox → DEV promotion workflow
- [ ] Update architecture diagrams
- [ ] Document sandbox use cases and policies

### Promotion Path: Sandbox → DEV

**Strategy Options**:

1. **Manual Cherry-Pick** (Recommended for POCs)
   ```bash
   # Test in sandbox
   git checkout -b poc/feature-name
   # ... make changes ...
   # Deploy to sandbox, test
   
   # Promote to DEV via PR
   git checkout main
   git cherry-pick <sandbox-commit>
   # Auto-deploys to DEV via publisher
   ```

2. **Extractor-Based** (For complex changes)
   ```bash
   # Extract from sandbox APIM
   gh workflow run run-extractor.yaml -f SOURCE_ENVIRONMENT=apim-bpimb-sb
   # Creates PR with sandbox changes
   # Review and merge to promote to DEV
   ```

3. **Branch-Based** (For coordinated releases)
   ```bash
   # Develop on sandbox branch
   git checkout -b sandbox/release-v2
   # Deploy to sandbox environment only
   
   # Promote to DEV when ready
   git checkout main
   git merge sandbox/release-v2
   # Auto-deploys to DEV
   ```

### Testing Strategy
- [ ] Create ephemeral test VM in same VNet
- [ ] Test internal connectivity to sandbox APIM
- [ ] Verify API policies work correctly
- [ ] Test Key Vault integration
- [ ] Verify backend connectivity

---

## 🔄 Initiative 2: Change Extractor Source to DEV

### Objective
Make `niaid-bpimb-apim-dev` the primary source for extraction workflow, while keeping `apim-daids-connect` available. Optionally support sandbox-to-DEV promotion via extraction.

### Current State
- **Extractor Source**: `apim-daids-connect` (DAIDS DEV)
- **Deployment Targets**: DEV, QA
- **Flow**: DAIDS → Git → DEV/QA

### Target State - Option A (Recommended)
- **Extractor Source**: `niaid-bpimb-apim-dev` (BPIMB DEV)
- **Deployment Targets**: QA, Sandbox
- **Flow**: DEV → Git → QA/Sandbox
- **Use Case**: DEV is production-like, QA mirrors it, Sandbox for experiments

### Target State - Option B (Alternative)
- **Extractor Source**: `niaid-bpimb-apim-sb` (BPIMB Sandbox)
- **Deployment Targets**: DEV, QA
- **Flow**: Sandbox → Git → DEV → QA
- **Use Case**: All changes start in Sandbox, promoted to DEV via extraction, then QA

**Decision Required**: Choose Option A or Option B based on workflow preferences.

### Rationale

**Option A (DEV as Source)**:
- ✅ DEV becomes the "source of truth" for API configurations
- ✅ Sandbox can be used for experimentation without affecting version control
- ✅ QA mirrors DEV configuration (current behavior)
- ✅ Simpler promotion path (manual cherry-pick or PR)
- ⚠️ Sandbox changes must be manually promoted

**Option B (Sandbox as Source)**:
- ✅ All changes start in Sandbox (isolated development)
- ✅ Automated promotion via extraction workflow
- ✅ Git always reflects what's deployed to Sandbox first
- ⚠️ More complex workflow
- ⚠️ DEV becomes a deployment target instead of source of truth

**Both Options**:
- DAIDS remains available for legacy extraction if needed
- Can switch between options as needed

### Changes Required

#### Workflow Updates
- [ ] Update `run-extractor.yaml`:
  - **Option A**: Change default environment from `apim-daids-connect` to `apim-bpimb-dev`
  - **Option B**: Change default environment from `apim-daids-connect` to `apim-bpimb-sb`
  - Add all three as environment choices: `apim-daids-connect`, `apim-bpimb-dev`, `apim-bpimb-sb`
  - Update documentation in workflow to explain when to use each source

#### Configuration Updates
- [ ] Review `configuration.extractor.yaml`:
  - Verify it works with DEV as source (Option A)
  - Verify it works with Sandbox as source (Option B)
  - Update API filters if needed
  - Ensure named values are extracted correctly
  - Consider creating separate extractor configs:
    - `configuration.extractor.dev.yaml` (for Option A)
    - `configuration.extractor.sandbox.yaml` (for Option B)

#### Documentation Updates
- [ ] Update README.md:
  - Document chosen extractor flow (Option A or B)
  - Document when to use each extractor source:
    - Sandbox: For promoting experimental features
    - DEV: For capturing production-like state
    - DAIDS: For legacy/reference extraction
  - Update architecture diagrams with chosen flow
  - Update Quick Start guide with new extraction workflow

#### Testing
- [ ] **Option A**: Run extraction from DEV: `gh workflow run run-extractor.yaml -f SOURCE_ENVIRONMENT=apim-bpimb-dev`
- [ ] **Option B**: Run extraction from Sandbox: `gh workflow run run-extractor.yaml -f SOURCE_ENVIRONMENT=apim-bpimb-sb`
- [ ] Verify PR created with correct changes
- [ ] Compare with previous DAIDS extractions
- [ ] Ensure no regressions in downstream deployments (QA for Option A, DEV/QA for Option B)

### Migration Plan

**Phase 1: Preparation** (Day 1)
1. **DECISION POINT**: Choose Option A (DEV as source) or Option B (Sandbox as source)
2. Run final extraction from DAIDS to capture current state
3. Merge DAIDS extraction PR
4. Tag current state: `pre-extractor-migration`

**Phase 2: Switch** (Day 1)
1. Update `run-extractor.yaml` to use chosen source as default (DEV or Sandbox)
2. Add all three environments as choices in workflow
3. Update documentation to reflect chosen flow
4. Commit and push changes

**Phase 3: Validation** (Day 1)
1. Run extraction from chosen source (DEV or Sandbox)
2. Review differences from DAIDS baseline
3. Merge if changes are expected
4. Monitor deployments to downstream environments

**Phase 4: Ongoing** (Week 1)
- **Option A**: Run weekly extractions from DEV, monitor QA deployments
- **Option B**: Run extractions from Sandbox after completing POCs, monitor DEV/QA deployments
- Compare with DAIDS occasionally to detect drift
- Document any discrepancies

### Rollback Plan
If new extraction source causes issues:
```bash
# Revert extractor workflow changes
git revert <commit-sha>
git push

# Or manually run extraction from DAIDS
gh workflow run run-extractor.yaml -f SOURCE_ENVIRONMENT=apim-daids-connect

# Or manually run from previous working source
gh workflow run run-extractor.yaml # Will use old default config
```

---

## 🏭 Initiative 3: Create Production Environment

### Objective
Create `niaid-bpimb-apim-prod` in production subscription to support production API deployments.

### Resources to Create

#### Azure Resources
- **Subscription**: `NIH.NIAID.AzureSTRIDES_Prod` (NEW - different from DEV/QA)
- **Resource Group**: `niaid-bpimb-apim-prod-rg`
- **APIM Service**: `niaid-bpimb-apim-prod`
- **Location**: TBD (assess existing NIAID-APIM-Prod)
- **Tier**: Premium or Standard (for production SLA)

#### Pre-Implementation Assessment

**Assess Existing NIAID-APIM-Prod**:
- [ ] Document subscription ID
- [ ] Document resource group name
- [ ] Document networking configuration:
  - VNet name and address space
  - Subnet name and address range
  - Private IP address allocation
  - NSG rules
  - Peering configurations
  - ExpressRoute/VPN connections
- [ ] Document APIM configuration:
  - SKU and capacity
  - Gateway URL
  - Custom domains
  - SSL certificates
  - Virtual network type (internal/external)
- [ ] Document RBAC assignments
- [ ] Document monitoring/logging:
  - Application Insights
  - Log Analytics workspace
  - Diagnostic settings
- [ ] Document integration points:
  - Key Vault instances
  - Backend services
  - Azure AD app registrations
  - Managed identities
- [ ] Document compliance requirements:
  - Data residency
  - Encryption requirements
  - Audit logging
  - Network isolation

#### Networking (mirror existing or create new)
- [ ] VNet configuration
  - Option A: Use existing prod VNet
  - Option B: Create new VNet for BPIMB APIM
- [ ] Subnet allocation
- [ ] Private endpoint configuration
- [ ] DNS configuration (private DNS zones)
- [ ] Network security groups
- [ ] Firewall rules / App Gateway rules
- [ ] Internal gateway URL: `niaid-bpimb-apim-prod.azure-api.net`

#### Service Principal
- [ ] Create Azure AD App Registration: `apiops-prod-sp`
- [ ] Create client secret (store in Prod Key Vault)
- [ ] Assign RBAC permissions:
  - `API Management Service Contributor` on `niaid-bpimb-apim-prod`
  - `Reader` on `niaid-bpimb-apim-prod-rg`
  - `Key Vault Secrets User` on Prod Key Vault
- [ ] Document credentials in secure location (separate from DEV/QA)

#### GitHub Secrets/Environments
- [ ] Create GitHub environment: `apim-bpimb-prod`
- [ ] Add secrets to `apim-bpimb-prod` environment:
  - `AZURE_CLIENT_ID` (from prod SP)
  - `AZURE_CLIENT_SECRET` (from prod SP)
  - `AZURE_TENANT_ID` (may differ from DEV)
  - `AZURE_SUBSCRIPTION_ID` (NIH.NIAID.AzureSTRIDES_Prod)
  - `AZURE_RESOURCE_GROUP_NAME` = `niaid-bpimb-apim-prod-rg`
  - `API_MANAGEMENT_SERVICE_NAME` = `niaid-bpimb-apim-prod`
  - `APIM_SUBSCRIPTION_KEY` (for testing)
- [ ] Create approval environment: `approve-apim-bpimb-prod`
- [ ] Configure required reviewers (multiple approvers for prod)
- [ ] Enable environment protection rules:
  - Required reviewers: 2+ people
  - Deployment branches: main only
  - Wait timer: 5-10 minutes (to allow for review)

#### Configuration Files
- [ ] Create `configuration.production.yaml` (**NOTE: This already exists!**)
  - Review existing file
  - Update for new prod APIM service name
  - Update resource group
  - Update gateway URLs
  - Update backend service URLs (prod backends)
  - Update Key Vault references (prod Key Vault)
  - Review named values for prod-specific settings

#### Workflow Updates
- [ ] Update `run-publisher.yaml` to support production
  - Add production deployment job (after QA)
  - Add **strict** approval gate for production (2+ reviewers)
  - Add production test job
  - Add cleanup job for production
  - Add tagging job: `deploy-prod-{timestamp}-{sha}`
  - Add production-specific validation:
    - Breaking change detection
    - API specification validation
    - Policy syntax validation
- [ ] Update `rollback-deployment.yaml` to support production
  - **Enhanced safety for prod rollbacks**
  - Required approval for ALL prod rollbacks
  - Automatic notifications to team
- [ ] Update `cleanup-orphaned-apis.yaml` to support production
- [ ] Update `test-apis-ephemeral.yaml` to test production APIs

#### Testing Strategy
- [ ] Create prod-specific test suite (more comprehensive than DEV/QA)
- [ ] Create ephemeral test VM in prod VNet
- [ ] Test internal connectivity to prod APIM
- [ ] Verify API policies work correctly
- [ ] Test Key Vault integration
- [ ] Verify backend connectivity to prod services
- [ ] Load testing / performance validation
- [ ] Security scanning

#### Migration from Existing NIAID-APIM-Prod

**Strategy TBD** - Options:

1. **Parallel Run** (Recommended)
   - Deploy to new `niaid-bpimb-apim-prod` alongside existing
   - Gradually migrate APIs from old to new
   - Test thoroughly before cutover
   - Keep old APIM running as fallback

2. **Big Bang Migration**
   - Extract from existing NIAID-APIM-Prod
   - Deploy to new `niaid-bpimb-apim-prod`
   - DNS cutover
   - Decommission old APIM

3. **Incremental Migration**
   - Migrate APIs one by one
   - Use routing/traffic splitting
   - Validate each API before full cutover

#### Documentation
- [ ] Update README.md:
  - Add production environment to table
  - Document production deployment workflow
  - Add production-specific guidelines
  - Update architecture diagrams
- [ ] Create PRODUCTION-DEPLOYMENT.md:
  - Pre-deployment checklist
  - Approval process
  - Rollback procedures
  - Incident response plan
  - Change management process
- [ ] Update runbooks for production operations

---

## 📋 Implementation Timeline

### Day 1 (January 13, 2026)

**Morning** (9 AM - 12 PM):
- [ ] Assessment of existing NIAID-APIM-Prod
- [ ] Network architecture planning
- [ ] Service principal creation for all new environments

**Afternoon** (1 PM - 5 PM):
- [ ] Create sandbox environment resources
- [ ] Configure sandbox networking
- [ ] Create GitHub environments and secrets
- [ ] Update workflows for sandbox support

### Day 2 (January 14, 2026)

**Morning** (9 AM - 12 PM):
- [ ] Test sandbox deployment end-to-end
- [ ] Switch extractor source to DEV
- [ ] Validate extractor changes

**Afternoon** (1 PM - 5 PM):
- [ ] Create production environment resources
- [ ] Configure production networking
- [ ] Configure production GitHub environments

### Day 3 (January 15, 2026)

**All Day**:
- [ ] Production workflow development
- [ ] Production testing
- [ ] Documentation updates
- [ ] Team training on new environments

---

## 🎯 Success Criteria

### Sandbox Environment
- ✅ Can deploy APIs to sandbox independently
- ✅ Can test POCs in sandbox without affecting DEV
- ✅ Can promote successful POCs to DEV via PR
- ✅ Ephemeral tests run successfully in sandbox
- ✅ Rollback works for sandbox deployments

### Extractor Changes
- ✅ Extraction from DEV works correctly
- ✅ No regressions in QA deployments
- ✅ DAIDS extraction still available if needed
- ✅ Documentation clearly explains new flow

### Production Environment
- ✅ Production APIM created and accessible
- ✅ Networking mirrors existing prod configuration
- ✅ Approval gates enforce 2+ reviewers
- ✅ Tests validate production deployments
- ✅ Rollback workflow tested in production
- ✅ Migration plan documented and approved

---

## 🚨 Risk Assessment

### High Risk
- **Production deployment failures**: Mitigated by strict approval gates, comprehensive testing
- **Network connectivity issues**: Mitigated by thorough network assessment, testing
- **Subscription/permission issues**: Mitigated by early SP creation and testing

### Medium Risk
- **Extractor source change causing drift**: Mitigated by comparison testing, rollback plan
- **Sandbox promotion workflow confusion**: Mitigated by clear documentation
- **Resource naming conflicts**: Mitigated by using consistent naming convention

### Low Risk
- **Cost overruns from new environments**: Monitor spending, use lower SKUs for sandbox
- **GitHub Actions quota limits**: May need to optimize workflow concurrency

---

## 📞 Key Contacts

- **Azure Subscription Owner**: TBD
- **Network Team**: TBD
- **Security Team**: TBD (for prod approval)
- **API Consumers**: TBD (for prod testing)

---

## 📝 Questions to Resolve

1. **Sandbox**:
   - [ ] What SKU/tier for sandbox? (Developer tier for cost savings?)
   - [ ] Should sandbox auto-deploy on commits to sandbox branch?
   - [ ] Who approves sandbox deployments?

2. **Extractor**:
   - [ ] **CRITICAL**: Choose Option A (DEV as source) or Option B (Sandbox as source)?
   - [ ] If Option A: How often should we extract from DEV? (weekly/on-demand?)
   - [ ] If Option B: Should extraction be automatic after Sandbox changes or manual?
   - [ ] Should we maintain scheduled extractions from DAIDS for comparison/audit?
   - [ ] Do we need separate extractor configuration files for each source?

3. **Production**:
   - [ ] What is the timeline for decommissioning existing NIAID-APIM-Prod?
   - [ ] Who are the required approvers for production deployments?
   - [ ] What is the maintenance window for production changes?
   - [ ] Do we need blue/green deployment for production?
   - [ ] What is the disaster recovery plan?

4. **General**:
   - [ ] Do we need separate repositories for different environments?
   - [ ] Should we implement feature flags for gradual rollout?
   - [ ] What monitoring/alerting is needed for production?

---

## 📚 Reference Documentation

- [Azure APIM Networking Documentation](https://docs.microsoft.com/azure/api-management/virtual-network-concepts)
- [GitHub Environments Documentation](https://docs.github.com/en/actions/deployment/targeting-different-environments)
- [APIops Toolkit](https://github.com/Azure/apiops)
- Current README.md in this repository
- Existing `configuration.production.yaml` file

---

## Status Tracking

Last Updated: January 12, 2026
Next Review: January 13, 2026 (start of implementation)

**Overall Status**: 🟡 Planning Complete, Ready for Implementation
