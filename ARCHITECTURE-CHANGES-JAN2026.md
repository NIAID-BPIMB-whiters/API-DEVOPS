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

### Promotion Path: Sandbox → DEV (Manual Process)

**Use Case**: Successfully tested POC in Sandbox needs to be promoted to DEV environment.

**Important**: This is a **manual, selective process** - not all sandbox changes should be promoted. Only successful, tested POCs should move to DEV.

---

#### Method 1: Manual File Copy (Recommended for Simple Changes)

**Best for**: Single API changes, policy updates, simple configuration changes

**Steps**:

1. **Export API configuration from Sandbox APIM**
   ```powershell
   # Login to Azure
   az login
   az account set --subscription <subscription-id>
   
   # Export specific API from Sandbox
   az apim api export `
     --resource-group niaid-bpimb-apim-sb-rg `
     --service-name niaid-bpimb-apim-sb `
     --api-id <api-id> `
     --export-format OpenApiJson `
     --file-path ./sandbox-export/<api-name>.json
   
   # Export API policy
   az apim api policy show `
     --resource-group niaid-bpimb-apim-sb-rg `
     --service-name niaid-bpimb-apim-sb `
     --api-id <api-id> `
     --output xml > ./sandbox-export/<api-name>-policy.xml
   ```

2. **Review and update configuration files in repository**
   ```bash
   # Create feature branch
   git checkout -b feature/sandbox-poc-<feature-name>
   
   # Manually update files in apimartifacts/apis/<api-name>/
   # - Update specification.yaml with exported OpenAPI spec
   # - Update policy.xml with exported policy
   # - Update apiInformation.json if needed
   
   # Update for DEV environment specifics
   # - Change backend URLs if needed
   # - Update named values references
   # - Adjust environment-specific settings
   ```

3. **Test in local/preview mode**
   ```bash
   # Validate OpenAPI spec
   npx @stoplight/spectral-cli lint apimartifacts/apis/<api-name>/specification.yaml
   
   # Validate policy syntax (manual review)
   # Check for sandbox-specific values that need to change
   ```

4. **Create PR and deploy to DEV**
   ```bash
   git add apimartifacts/
   git commit -m "feat: Promote <feature-name> POC from Sandbox to DEV"
   git push origin feature/sandbox-poc-<feature-name>
   
   # Create PR
   gh pr create --title "Promote <feature-name> from Sandbox" \
     --body "Successfully tested POC in Sandbox. Ready for DEV deployment."
   
   # After PR approval, merge triggers auto-deployment to DEV
   ```

---

#### Method 2: Azure Portal Manual Configuration (For Complex Changes)

**Best for**: Complex configurations, multiple related resources, policies with dependencies

**Steps**:

1. **Document Sandbox Configuration**
   - Screenshot or document all settings in Sandbox APIM portal
   - Note API operations, policies, products, subscriptions
   - Document backend services, named values, certificates

2. **Manually Recreate in DEV APIM Portal**
   - Login to Azure Portal → Navigate to niaid-bpimb-apim-dev
   - Recreate API with same operations
   - Copy/paste policies (update environment-specific values)
   - Configure products, subscriptions, etc.

3. **Extract DEV to Sync Repository**
   ```bash
   # After manual changes in DEV, extract to capture them
   gh workflow run run-extractor.yaml \
     -f SOURCE_ENVIRONMENT=apim-bpimb-dev \
     -f CONFIGURATION_YAML_PATH="Extract All APIs"
   
   # Review and merge the extraction PR
   # This ensures Git repo stays in sync with DEV
   ```

---

#### Method 3: Extractor-Based (For Full Environment Sync)

**Best for**: Multiple APIs, comprehensive POC with many resources, testing extraction workflow

**Steps**:

1. **Run Extractor from Sandbox**
   ```bash
   gh workflow run run-extractor.yaml \
     -f SOURCE_ENVIRONMENT=apim-bpimb-sb \
     -f CONFIGURATION_YAML_PATH="Extract All APIs"
   ```

2. **Review Extraction PR Carefully**
   - Check all files in the PR
   - **Remove any Sandbox-only configs** that shouldn't go to DEV
   - **Update environment-specific values**:
     - Backend URLs
     - Named values
     - Key Vault references
     - Resource IDs

3. **Selective Promotion**
   ```bash
   # Checkout extraction PR branch
   gh pr checkout <pr-number>
   
   # Manually remove unwanted files
   git rm apimartifacts/apis/<sandbox-only-api>/
   
   # Edit files to change sandbox-specific values
   # Update configuration.dev.yaml references
   
   # Commit selective changes
   git add -A
   git commit -m "refactor: Keep only <feature> from sandbox extraction"
   git push
   
   # Merge PR to deploy to DEV
   ```

---

#### Method 4: Infrastructure as Code (For Repeatable Deployments)

**Best for**: Standardized POC promotion, automation, repeatable process

**Steps**:

1. **Create Deployment Script**
   ```powershell
   # scripts/promote-sandbox-to-dev.ps1
   param(
       [string]$ApiId,
       [string]$ApiName
   )
   
   # Export from Sandbox
   az apim api export --resource-group niaid-bpimb-apim-sb-rg `
     --service-name niaid-bpimb-apim-sb --api-id $ApiId `
     --file-path "./temp/$ApiName.json"
   
   # Transform for DEV environment
   # (Add transformation logic here)
   
   # Update repository files
   Copy-Item "./temp/$ApiName.json" `
     "apimartifacts/apis/$ApiName/specification.yaml"
   
   # Commit and push
   git checkout -b "feature/promote-$ApiName"
   git add apimartifacts/apis/$ApiName/
   git commit -m "feat: Promote $ApiName from Sandbox"
   git push origin "feature/promote-$ApiName"
   ```

2. **Run Script**
   ```powershell
   .\scripts\promote-sandbox-to-dev.ps1 -ApiId "test-api" -ApiName "test"
   ```

---

### Promotion Checklist

Before promoting from Sandbox to DEV, ensure:

- [ ] POC fully tested in Sandbox environment
- [ ] All Sandbox-specific configurations identified
- [ ] Environment-specific values updated for DEV:
  - [ ] Backend service URLs
  - [ ] Named values / environment variables
  - [ ] Key Vault secret references
  - [ ] Subscription keys
  - [ ] OAuth/AAD settings
- [ ] API policies reviewed and updated
- [ ] Breaking changes documented
- [ ] Team notified of upcoming DEV deployment
- [ ] Rollback plan identified (previous DEV deployment tag)

### Post-Promotion Validation

After promoting to DEV:

1. **Run DEV Tests**
   ```bash
   gh run list --workflow=test-apis-ephemeral.yaml --limit 1
   gh run view <run-id>
   ```

2. **Verify API Functionality**
   ```bash
   # Test API endpoint
   curl -H "Ocp-Apim-Subscription-Key: $DEV_KEY" \
     https://niaid-bpimb-apim-dev.azure-api.net/<api-path>
   ```

3. **Monitor for Issues**
   - Check Application Insights for errors
   - Review APIM analytics
   - Test from consumer perspective

4. **Extract from DEV (Optional)**
   ```bash
   # If changes were made directly in portal, extract to sync repo
   gh workflow run run-extractor.yaml \
     -f SOURCE_ENVIRONMENT=apim-bpimb-dev
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
Make `niaid-bpimb-apim-dev` the primary source for extraction workflow (DEV → QA → PROD pipeline), while keeping `apim-daids-connect` available for legacy extraction.

### Current State
- **Extractor Source**: `apim-daids-connect` (DAIDS DEV)
- **Deployment Targets**: DEV, QA
- **Flow**: DAIDS → Git → DEV/QA

### Target State ✅ **DECISION MADE**
- **Primary Flow (Automated)**: `DEV → Git → QA → PROD`
  - **Extractor Source**: `niaid-bpimb-apim-dev` (BPIMB DEV)
  - **Deployment Targets**: QA, PROD
  - **Process**: Extract from DEV → PR → Merge → Auto-deploy to QA → Approve → Deploy to PROD
  
- **Sandbox Flow (Manual Promotion)**: `Sandbox → DEV`
  - **Purpose**: POC development and experimentation
  - **Process**: Manual steps to promote successful POCs from Sandbox to DEV (documented below)
  - **NOT extraction-based**: Sandbox does not feed into automated extraction workflow

- **Legacy Flow (On-Demand)**: `DAIDS → Git`
  - **Extractor Source**: `apim-daids-connect` (DAIDS DEV)
  - **Process**: Manual extraction for reference/comparison
  - **Use Case**: Audit, drift detection, legacy API reference

### Rationale

**Why DEV as Primary Extractor Source**:
- ✅ DEV becomes the "source of truth" for production-bound configurations
- ✅ QA mirrors DEV (validation environment)
- ✅ PROD mirrors QA (production deployment)
- ✅ Clear promotion path: DEV → QA → PROD
- ✅ Extraction workflow aligns with deployment pipeline
- ✅ Simpler to understand and maintain

**Why Sandbox Uses Manual Promotion (Not Extraction)**:
- ✅ Sandbox is for experimentation and POCs
- ✅ Not all sandbox changes should be promoted
- ✅ Manual review ensures only successful POCs move to DEV
- ✅ Keeps extraction workflow focused on DEV → QA → PROD pipeline
- ✅ Prevents accidental promotion of experimental/broken configs
- ✅ Allows selective feature promotion

**Why Keep DAIDS Extraction Available**:
- ✅ Historical reference for existing DAIDS APIs
- ✅ Drift detection between DAIDS and BPIMB environments
- ✅ Legacy API documentation
- ✅ Comparison/audit purposes

### Changes Required

#### Workflow Updates
- [ ] Update `run-extractor.yaml`:
  - Change default environment from `apim-daids-connect` to `apim-bpimb-dev`
  - Add all three as environment choices: `apim-daids-connect`, `apim-bpimb-dev`, `apim-bpimb-sb`
  - Update documentation in workflow:
    - `apim-bpimb-dev` (default): For DEV → QA → PROD pipeline
    - `apim-bpimb-sb`: For troubleshooting/comparing sandbox state (manual promotion to DEV)
    - `apim-daids-connect`: For legacy extraction and drift detection

#### Configuration Updates
- [ ] Review `configuration.extractor.yaml`:
  - Verify it works with DEV as default source
  - Update API filters if needed for DEV environment
  - Ensure named values are extracted correctly
  - Test extraction from Sandbox (optional, for comparison)

#### Documentation Updates
- [ ] Update README.md:
  - Document extractor flow: DEV → QA → PROD (automated)
  - Document Sandbox → DEV promotion (manual, documented above)
  - Document when to use each extractor source:
    - DEV (default): For DEV → QA → PROD pipeline
    - Sandbox: For troubleshooting, comparison (not for promotion)
    - DAIDS: For legacy/reference extraction, drift detection
  - Update architecture diagrams with DEV as primary source
  - Update Quick Start guide with new extraction workflow
  - Add Sandbox → DEV manual promotion guide to README

#### Testing
- [ ] Run extraction from DEV: `gh workflow run run-extractor.yaml -f SOURCE_ENVIRONMENT=apim-bpimb-dev`
- [ ] Verify PR created with correct changes
- [ ] Compare with previous DAIDS extractions to detect drift
- [ ] Ensure no regressions in QA deployment
- [ ] Test Sandbox extraction (optional): `gh workflow run run-extractor.yaml -f SOURCE_ENVIRONMENT=apim-bpimb-sb`

### Migration Plan

**Phase 1: Preparation** (Day 1-2)
1. ✅ **DECISION CONFIRMED**: DEV as primary extractor source
2. Run final extraction from DAIDS to capture current state
3. Merge DAIDS extraction PR if changes exist
4. Tag current state: `pre-extractor-migration`

**Phase 2: Switch** (Day 2)
1. Update `run-extractor.yaml` to use DEV as default source
2. Keep all three environments as choices (DEV, Sandbox, DAIDS)
3. Update documentation to reflect new flow
4. Commit and push changes

**Phase 3: Validation** (Day 2-3)
1. Run extraction from DEV: `gh workflow run run-extractor.yaml`
2. Review differences from DAIDS baseline
3. Merge if changes are expected (environment-specific differences)
4. Monitor QA deployment after merge
5. Verify QA mirrors DEV correctly

**Phase 4: Ongoing** (Week 1+)
- Run weekly scheduled extractions from DEV
- Monitor QA and PROD deployments
- Occasionally extract from DAIDS for drift detection
- Document Sandbox → DEV promotions in PR descriptions
- Extract from Sandbox only for troubleshooting/comparison

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
   - [x] **DECISION MADE**: DEV as primary extractor source for DEV → QA → PROD pipeline
   - [ ] How often should we extract from DEV? (weekly/on-demand/both?)
   - [ ] Should we schedule automatic weekly extractions from DEV?
   - [ ] Should we maintain periodic extractions from DAIDS for comparison/audit?
   - [ ] Create promotion script template for Sandbox → DEV?

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
