# API Development Workflow & Versioning Strategy

**Document Version**: 1.0  
**Last Updated**: January 6, 2026  
**Owner**: NIH/NIAID/BPIMB

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [The Core Problem](#the-core-problem)
3. [Development Workflow Strategy](#development-workflow-strategy)
4. [Using APIM Revisions for Development](#using-apim-revisions-for-development)
5. [Branching Strategy](#branching-strategy)
6. [When to Extract & Commit](#when-to-extract--commit)
7. [API Consumer Versioning](#api-consumer-versioning)
8. [Implementation Guidelines](#implementation-guidelines)
9. [Version Lifecycle Management](#version-lifecycle-management)
10. [Testing Strategy](#testing-strategy)

---

## Executive Summary

This document addresses two distinct versioning challenges:

1. **Development Workflow**: How to develop APIs in DAIDS_DEV without committing every small change to the repository
2. **API Consumer Versioning**: How to manage API versions for consumers (v1, v2, etc.)

### The Core Problem

**Current Situation**:
- DAIDS_DEV is your development/sandbox environment
- Extractor captures ALL changes from DAIDS_DEV
- You want to iterate quickly without polluting the repository
- Only "ready" changes should be committed and deployed to DEV/QA

**Key Recommendations**:

**For Development Workflow**:
1. Use **APIM Revisions** for in-progress development (don't extract these)
2. Extract only when a feature is **complete and tested**
3. Use **feature branches** in Git for work-in-progress
4. Manually trigger extractor (don't run on every change)

**For API Consumer Versioning**:
1. Use **URL path (Segment) versioning** (`/v1/`, `/v2/`)
2. Use **Revisions** for non-breaking changes within a version
3. Maintain **maximum 2 active versions** simultaneously

---

## The Core Problem

### Current Workflow Issue

```
Developer makes small change in DAIDS_DEV
         ↓
Run extractor (captures everything)
         ↓
Commit to repository (noise!)
         ↓
Publisher deploys to DEV/QA (half-finished features!)
         ↓
😞 Repository cluttered with WIP commits
```

### Desired Workflow

```
Developer iterates in DAIDS_DEV (multiple small changes)
         ↓
Feature complete? → No → Keep working in DAIDS_DEV
         ↓ Yes
Run extractor (capture completed work)
         ↓
Commit to feature branch
         ↓
PR review → Merge to main
         ↓
Publisher deploys to DEV/QA
         ↓
😊 Clean repository with meaningful commits
```

---

## Development Workflow Strategy

### Option 1: Use APIM Revisions for Development (RECOMMENDED)

**How It Works**:
- Create a **new revision** of your API for active development
- Work on the revision in DAIDS_DEV (not "current")
- When ready, make it **current** and extract
- Revisions don't affect published APIs until made current

**Benefits**:
- ✅ Develop without affecting current API
- ✅ Test changes in isolation
- ✅ Extract only when ready
- ✅ Built-in Azure APIM feature

**Process**:

```bash
# 1. Create new revision in DAIDS_DEV Portal
API → Revisions → Add revision
Revision: 2
Description: "Adding new filtering parameters"

# 2. Develop in revision 2
# Make changes to revision 2 in Portal or via code
# Revision 2 is accessible at: https://apim.../api;rev=2

# 3. Test revision 2
# Use revision parameter: ;rev=2 in URL

# 4. When satisfied, make revision 2 current
Revisions → Release → Make current

# 5. NOW extract
gh workflow run run-extractor.yaml -f ENVIRONMENT=daids_dev

# 6. Commit the completed work
git add apimartifacts/
git commit -m "feat: Add filtering parameters to CRMS API"
git push
```

**Revision Naming Convention**:
```
Revision 1: Current production version
Revision 2: Feature - Add filtering (dev in progress)
Revision 3: Feature - Update authentication (dev in progress)
```

### Option 2: Use Feature Branches + Manual Extraction

**How It Works**:
- Develop in DAIDS_DEV freely
- Don't run extractor automatically
- When feature complete:
  1. Run extractor manually
  2. Commit to feature branch
  3. PR review
  4. Merge to main

**Benefits**:
- ✅ Flexible development
- ✅ Clean commit history
- ✅ Code review before deployment

**Process**:

```bash
# 1. Create feature branch
git checkout -b feature/crms-api-filtering

# 2. Develop in DAIDS_DEV (multiple days/iterations)
# No extraction yet!

# 3. Feature complete? Run extractor
gh workflow run run-extractor.yaml \
  -f ENVIRONMENT=daids_dev \
  -f CREATE_PULL_REQUEST=true \
  -f FEATURE_BRANCH=feature/crms-api-filtering

# 4. Review PR, merge when ready
# Publisher deploys to DEV/QA only after merge

# 5. Clean up feature branch
git branch -d feature/crms-api-filtering
```

### Option 3: Dedicated Development API Instance

**How It Works**:
- Use DAIDS_DEV for active development (don't extract)
- When ready, **manually** deploy to a "staging" API in DAIDS_DEV
- Extract from the "staging" API only

**Benefits**:
- ✅ Complete isolation
- ✅ Multiple developers can work simultaneously
- ❌ More complex setup

**Structure**:
```
DAIDS_DEV Environment:
├── crms-api (development - not extracted)
├── crms-api-staging (ready for extraction)
└── opentext (development - not extracted)
```

### Recommended Approach for NIAID

**Combination of Revision + Feature Branches**:

1. **Small changes** (bug fixes, tweaks): Edit current revision, extract immediately
2. **Medium features** (1-2 days): Use revisions, extract when complete
3. **Large features** (multi-day): Use revisions + feature branch

**Decision Tree**:
```
Is this a breaking change?
│
├─ Yes → Create new API version (v1 → v2)
│         Use feature branch for development
│         Extract when complete
│
└─ No → Backwards compatible change
         │
         ├─ Quick fix (<1 hour)?
         │   └─ Edit current revision
         │      Extract immediately
         │
         └─ New feature (>1 day)?
             └─ Create new revision
                Develop in revision
                Extract when ready
                Feature branch for PR review
```

---

## Using APIM Revisions for Development

### What Are Revisions?

**Revisions** allow you to make changes to an API without affecting the current version. Think of them as "drafts" or "development branches" within APIM.

**Key Concepts**:
- Only **one revision** is "current" (the published version)
- **Other revisions** are accessible via `;rev=N` URL parameter
- Revisions are **sequential** (rev 1, 2, 3...)
- Making a revision current **replaces** the previous current revision

### Creating a Revision

**Option A: Azure Portal**
```
1. Navigate to APIM → APIs → [Your API]
2. Click "Revisions" tab
3. Click "+ Add revision"
4. Revision number: Auto-increments (e.g., 2)
5. Description: "Feature: Add bulk operations"
6. Create revision from: Current revision
7. Click "Create"
```

**Option B: Azure CLI**
```bash
az rest --method put \
  --uri "https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ApiManagement/service/{apim}/apis/{api};rev=2?api-version=2022-08-01" \
  --body @revision-config.json
```

### Developing in a Revision

**Access Non-Current Revision**:
```
Current API: https://api.niaid.nih.gov/crms-api/protocols
Revision 2:   https://api.niaid.nih.gov/crms-api/protocols;rev=2
```

**Testing Revision**:
```bash
# Test revision 2 before making it current
curl https://api.niaid.nih.gov/crms-api;rev=2/protocols \
  -H "Ocp-Apim-Subscription-Key: {key}"
```

### Making a Revision Current

**When to Make Current**:
- ✅ Feature complete and tested
- ✅ Ready for extraction and deployment
- ✅ Backward compatible (or version bumped)

**How to Make Current**:
```
Portal: Revisions → Select revision → "Make current"
```

**What Happens**:
- Previous "current" becomes historical
- New revision becomes the default (no `;rev=N` needed)
- This is when you extract!

### Revision Best Practices

**DO**:
- ✅ Use revisions for feature development
- ✅ Keep revision descriptions meaningful
- ✅ Test revisions before making current
- ✅ Make revision current BEFORE extracting

**DON'T**:
- ❌ Extract non-current revisions (they're WIP)
- ❌ Accumulate many revisions (clean up old ones)
- ❌ Make breaking changes in revisions (use new version instead)

---

## Branching Strategy

### Git Branch Workflow

**Branch Types**:

| Branch | Purpose | Lifetime | Extractor Runs? |
|--------|---------|----------|-----------------|
| `main` | Production-ready code | Permanent | ✅ On merge only |
| `feature/*` | New features/enhancements | Temporary | ✅ Manual, on completion |
| `bugfix/*` | Bug fixes | Temporary | ✅ Manual, when fixed |
| `hotfix/*` | Urgent production fixes | Temporary | ✅ Immediate |

**Workflow**:

```bash
# 1. Start feature
git checkout -b feature/crms-bulk-operations

# 2. Develop in DAIDS_DEV
# (Create APIM revision 2 for development)
# Work on revision 2 for several days...

# 3. Feature complete
# Make revision 2 current in DAIDS_DEV

# 4. Extract
gh workflow run run-extractor.yaml -f ENVIRONMENT=daids_dev

# 5. Commit extracted artifacts
git add apimartifacts/
git commit -m "feat(crms-api): Add bulk operations endpoint

- Added POST /protocols/batch for bulk creation
- Added validation for batch size (max 100)
- Updated OpenAPI specification
- Added policy for rate limiting bulk operations"

# 6. Push and create PR
git push origin feature/crms-bulk-operations
gh pr create --title "Add bulk operations to CRMS API" \
  --body "Closes #123"

# 7. After PR review and merge
# Publisher workflow automatically deploys to DEV → QA

# 8. Clean up
git checkout main
git pull
git branch -d feature/crms-bulk-operations
```

### Commit Message Convention

**Format**: `<type>(<scope>): <subject>`

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation only
- `policy`: Policy changes
- `config`: Configuration changes

**Examples**:
```
feat(crms-api): Add filtering by study phase
fix(opentext): Correct authentication header
refactor(merlin-api): Simplify error handling
policy(global): Add rate limiting
docs(readme): Update deployment instructions
```

---

## When to Extract & Commit

### Extraction Triggers

| Scenario | Extract? | Commit? | Branch | Notes |
|----------|----------|---------|--------|-------|
| **Quick fix** (<30 min) | ✅ Immediately | ✅ To main | `hotfix/*` | Fast-track deployment |
| **Small feature** (1-2 hours) | ✅ When complete | ✅ To main | `main` or `feature/*` | Simple, low-risk |
| **Medium feature** (1-2 days) | ✅ When tested | ✅ To feature branch | `feature/*` | Use revision |
| **Large feature** (>3 days) | ✅ When complete | ✅ To feature branch | `feature/*` | Use revision + PR review |
| **Breaking change** | ✅ After version bump | ✅ To feature branch | `feature/*` | New API version |
| **Experimental/POC** | ❌ Don't extract | ❌ Don't commit | - | Keep in DAIDS_DEV only |
| **Daily iteration** | ❌ Not yet | ❌ Not yet | - | Use revision |

### Filtering Non-Current API Versions

**Problem**: When using API version sets (v1, v2, v3), APIM marks only one version as "current" (`isCurrent: true`). However, the APIops extractor captures **ALL** versions, including deprecated ones.

**APIops Limitation** (as of v6.0.2):
- ❌ Extractor does **NOT** support filtering by `isCurrent` property
- ❌ No `includeNonCurrent: false` configuration option exists
- The extractor only uses `isCurrent` for naming conventions (current revision = root name, others get `;rev=N`)

**Recommended Solution**: Post-extraction cleanup script

Add this step to your extractor workflow:

```yaml
# .github/workflows/run-extractor.yaml
- name: Remove Non-Current API Versions
  if: github.event.inputs.FILTER_NON_CURRENT == 'true'
  shell: pwsh
  run: |
    # Find and remove APIs where isCurrent is false
    Write-Host "Filtering non-current API versions..."
    
    Get-ChildItem -Path "apimartifacts/apis" -Recurse -Filter "apiInformation.json" | 
      Where-Object { 
        $content = Get-Content $_.FullName -Raw | ConvertFrom-Json
        $isCurrent = $content.properties.isCurrent
        
        # Remove if explicitly marked as non-current
        if ($isCurrent -eq $false) {
          $apiName = $_.Directory.Name
          Write-Host "  Removing non-current API: $apiName"
          Remove-Item $_.Directory.FullName -Recurse -Force
          return $true
        }
        return $false
      }
    
    Write-Host "✅ Non-current API versions filtered"
```

**Alternative**: Manually list current versions in configuration.extractor.yaml

```yaml
# configuration.extractor.yaml
apis:
  - name: merlin-db          # Current version only
  - name: opentext           # Current version only
  - name: crms-api-qa        # Current version only
  # Do NOT include: merlin-db-v1-legacy, opentext-deprecated, etc.
```

**See Also**: README.md TODO #1 for detailed implementation options

### Extraction Checklist

Before running extractor:

- [ ] API changes are complete and tested
- [ ] Revision is made current (if using revisions)
- [ ] OpenAPI specification is updated
- [ ] Policies are finalized
- [ ] Backend configurations are correct
- [ ] Breaking changes are documented
- [ ] Version bumped if necessary

### Manual Extractor Workflow

**Disable Automatic Extraction** (if currently automatic):

```yaml
# .github/workflows/run-extractor.yaml
on:
  workflow_dispatch:  # Manual trigger only
    inputs:
      ENVIRONMENT:
        description: 'Environment to extract from'
        required: true
        type: choice
        options:
          - daids_dev
      
  # Remove schedule and push triggers
  # schedule:
  #   - cron: '0 2 * * *'  # REMOVED
```

**Run Extraction Manually**:

```bash
# From command line
gh workflow run run-extractor.yaml -f ENVIRONMENT=daids_dev

# Or from GitHub Actions UI
# Actions → Run workflow → Select branch → Run
```

---

## API Consumer Versioning

### When to Create a New API Version

**Use Semantic Versioning for Major Versions**: v1, v2, v3...

**Create New Version (v1 → v2) When**:
- Removing endpoints
- Changing request/response schemas (breaking)
- Changing authentication
- Renaming fields
- Changing data types

**Use Revision (v1.1, v1.2) When**:
- Adding new optional parameters
- Adding new endpoints
- Adding response fields (backwards compatible)
- Bug fixes

### Version Set Configuration

**Create Once Per API**:

```json
{
  "properties": {
    "displayName": "CRMS API",
    "versioningScheme": "Segment",
    "description": "Clinical Research Management System API"
  }
}
```

**URL Structure**:
```
v1: https://api.niaid.nih.gov/crms-api/v1/protocols
v2: https://api.niaid.nih.gov/crms-api/v2/protocols
```

### Recommended Strategy

**URL Path (Segment) Versioning**:
- Most visible and explicit
- GitOps-friendly (separate folders per version)
- Industry standard

**Repository Structure**:
```
apimartifacts/
  apis/
    crms-api-v1/              # Version 1
      apiInformation.json
      specification.yaml
    crms-api-v2/              # Version 2 (breaking changes)
      apiInformation.json
      specification.yaml
  version sets/
    crms-api-version-set/
      versionSetInformation.json
```

---

## Implementation Guidelines

### Scenario 1: Developing a New Feature (Non-Breaking)

**Example**: Add filtering parameters to CRMS API

```bash
# Day 1: Start development
# 1. Create APIM revision in Portal
API → Revisions → Add revision
Revision: 2
Description: "Add filtering by study phase and investigator"

# 2. Make changes to revision 2 in Portal
# - Update operations
# - Add query parameters
# - Test with ;rev=2 URL

# Day 2-3: Continue iterating
# Keep working on revision 2
# NO extraction yet!

# Day 4: Feature complete
# 1. Final testing of revision 2
curl "https://apim.../crms-api;rev=2/protocols?phase=Phase3"

# 2. Make revision 2 current
Revisions → Release

# 3. Create feature branch
git checkout -b feature/crms-filtering

# 4. Extract
gh workflow run run-extractor.yaml -f ENVIRONMENT=daids_dev

# Wait for extraction to complete...

# 5. Pull extracted changes
git pull origin feature/crms-filtering

# 6. Commit
git add apimartifacts/
git commit -m "feat(crms-api): Add filtering by phase and investigator"

# 7. Create PR
gh pr create

# 8. After merge, publisher deploys to DEV → QA
```

### Scenario 2: Making a Breaking Change (New Version)

**Example**: Change CRMS API response format (v1 → v2)

```bash
# 1. Create version set (if not exists)
# Portal: API Management → Version sets → Add
Display Name: CRMS API
Versioning Scheme: URL path segment

# 2. Associate v1 with version set
# Portal: CRMS-API-QA → Settings → Versioning
Version set: CRMS API
Version identifier: v1

# 3. Create v2 API
# Portal: APIs → Add version
Version identifier: v2
Versioning scheme: Path
New API path: crms-api/v2

# 4. Create revision for v2 development
# Work on v2 revision 2

# 5. Develop breaking changes in v2 revision
# Change response format, update OpenAPI spec

# 6. Make v2 revision current

# 7. Extract (captures both v1 and v2)
gh workflow run run-extractor.yaml -f ENVIRONMENT=daids_dev

# 8. Commit both versions
git checkout -b feature/crms-api-v2
git add apimartifacts/apis/crms-api-v1/
git add apimartifacts/apis/crms-api-v2/
git add apimartifacts/version\ sets/
git commit -m "feat(crms-api): Add v2 with new response format

BREAKING CHANGE: Response format changed from XML to JSON
- v1 continues to work for existing consumers
- v2 uses JSON-only responses
- Updated OpenAPI spec for v2"

# 9. Deploy both versions
# Publisher deploys v1 (no change) and v2 (new) to DEV/QA
```

### Scenario 3: Hotfix for Production Issue

**Example**: Fix authentication bug in OpenText API

```bash
# 1. Create hotfix branch
git checkout -b hotfix/opentext-auth-fix

# 2. Fix in DAIDS_DEV
# Edit current revision (no new revision needed for hotfix)

# 3. Test immediately

# 4. Extract right away
gh workflow run run-extractor.yaml -f ENVIRONMENT=daids_dev

# 5. Commit and push
git add apimartifacts/apis/opentext/
git commit -m "fix(opentext): Correct Authorization header format"
git push

# 6. Create PR with urgency label
gh pr create --label "hotfix" --label "priority:high"

# 7. Fast-track review and merge
# Publisher deploys to DEV → QA immediately
```

---

## Version Lifecycle Management

### Version States

```
[Development] → [Current] → [Deprecated] → [Retired]
      ↓              ↓            ↓             ↓
  DAIDS_DEV      DEV/QA      Limited         Removed
  (revisions)    (stable)    Support         (410 Gone)
```

### Deprecation Policy

**Minimum Notice**: 6 months before retirement

**Deprecation Headers**:
```xml
<policies>
    <inbound>
        <set-header name="Deprecation" exists-action="override">
            <value>true</value>
        </set-header>
        <set-header name="Sunset" exists-action="override">
            <value>Sat, 31 Dec 2026 23:59:59 GMT</value>
        </set-header>
        <set-header name="Link" exists-action="override">
            <value>&lt;https://api.niaid.nih.gov/crms-api/v2&gt;; rel="successor-version"</value>
        </set-header>
    </inbound>
</policies>
```

### Version Concurrency

**Maximum Active Versions**: 2 major versions simultaneously

**Example Timeline**:
```
Jan 2026: v1 (Current), v2 (Development)
Jun 2026: v1 (Current), v2 (Released)
Jul 2026: v1 (Deprecated), v2 (Current)
Jan 2027: v1 (Retired), v2 (Current)
```

---

## Testing Strategy

### Test Before Extraction

**Pre-Extraction Checklist**:

```bash
# 1. Test current revision in DAIDS_DEV
curl https://apim-daids-connect.../crms-api/protocols \
  -H "Ocp-Apim-Subscription-Key: {key}"

# 2. Validate OpenAPI spec
spectral lint apimartifacts/apis/crms-api/specification.yaml

# 3. Test with sample requests
newman run tests/crms-api.postman_collection.json

# 4. Verify policies
# Check policy.xml for syntax errors

# 5. If all pass → Extract!
```

### Multi-Version Testing

```yaml
# Test both v1 and v2 after extraction
strategy:
  matrix:
    version: [v1, v2]
steps:
  - name: Test ${{ matrix.version }}
    run: |
      newman run tests/crms-api-${{ matrix.version }}.postman_collection.json
```

---

## Quick Reference

### Development Workflow Decision Tree

```
Need to make API changes?
│
├─ Experimental/POC?
│   └─ Work in DAIDS_DEV only
│      ❌ Don't extract
│      ❌ Don't commit
│
├─ Quick fix (<1 hour)?
│   └─ Edit current revision
│      ✅ Extract immediately
│      ✅ Commit to main or hotfix branch
│
├─ New feature (1-3 days)?
│   └─ Create APIM revision
│      Work on revision
│      Make current when ready
│      ✅ Extract
│      ✅ Commit to feature branch
│
└─ Breaking change?
    └─ Create new API version
       Use revision for development
       Make current when ready
       ✅ Extract
       ✅ Commit to feature branch
       Document migration path
```

### Common Commands

```bash
# Manual extraction
gh workflow run run-extractor.yaml -f ENVIRONMENT=daids_dev

# Check extractor status
gh run list --workflow=run-extractor.yaml --limit 5

# Create feature branch
git checkout -b feature/api-name-feature

# Commit extracted changes
git add apimartifacts/
git commit -m "feat(api-name): Description"

# Create PR
gh pr create --title "Feature title" --body "Description"

# Test API revision
curl "https://apim.../api-name;rev=2/endpoint"
```

---

## Recommendations for NIAID

### Immediate Actions

1. **Disable Automatic Extraction**
   - Remove schedule trigger from run-extractor.yaml
   - Keep workflow_dispatch for manual runs

2. **Adopt Revision-Based Development**
   - Train team on APIM revisions
   - Document revision naming conventions
   - Make revisions current only when ready to deploy

3. **Implement Feature Branch Workflow**
   - All changes via feature branches
   - PR review before merge to main
   - Publisher runs only on main branch merges

### Long-Term Strategy

1. **Q1 2026**: Implement revision-based workflow
2. **Q2 2026**: Add version sets to production APIs
3. **Q3 2026**: Establish automated testing for revisions
4. **Q4 2026**: Document and share best practices

---

## References

- [Azure APIM Revisions](https://learn.microsoft.com/en-us/azure/api-management/api-management-revisions)
- [Azure APIM Versions](https://learn.microsoft.com/en-us/azure/api-management/api-management-versions)
- [Git Feature Branch Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/feature-branch-workflow)
- [Semantic Versioning](https://semver.org/)

---

## Change Log

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-01-06 | 1.0 | GitHub Copilot | Initial strategy document focused on development workflow |
| 2026-01-09 | 1.1 | GitHub Copilot | Added extractor filtering limitations and workarounds section |

---

## Approval

**Document Status**: ✅ Draft for Review

**Next Steps**:
1. Review with development team
2. Pilot with one API (recommended: CRMS-API-QA)
3. Update extractor workflow to manual-only
4. Train team on APIM revisions
5. Establish PR review process

### Existing APIs (as of January 6, 2026)

| API Name | Path | Versioning | Status | Notes |
|----------|------|------------|--------|-------|
| Merlin Vendor Lookup API | `/merlin` | ✅ Version Set (v1) | Production | Good example - already versioned |
| Merlin Vendor Lookup API | `/merlin` | ✅ Version Set (no version) | Production | Legacy version without explicit version |
| EDRMS-XDEV (OpenText) | `/opentext` | ❌ No versioning | Active | Needs versioning strategy |
| CRMS-API-QA | `/crms-api-qa` | ❌ No versioning | QA Testing | OAuth2 authenticated |
| OTCS MCP Server | `/otcs-mcp-server` | ❌ No versioning | Active | - |
| Merlin DB | `/merlin-db` | ❌ No versioning | Active | - |
| Demo Conference API | `/demo-conference-api` | ❌ No versioning | Demo/Test | - |
| Echo API | `/echo-api` | ❌ No versioning | Testing | Built-in test API |

### Observations

**Strengths**:
- Merlin API demonstrates successful version set implementation
- Clear path-based API organization
- All APIs using revision tracking (`apiRevision: "1"`)

**Gaps**:
- Most APIs lack explicit versioning
- No documented versioning guidelines
- No standardized deprecation process
- No version lifecycle documentation

---

## Versioning Approaches

Azure APIM supports three primary versioning schemes:

### 1. URL Path (Segment) Versioning ✅ **RECOMMENDED**

**Format**: `https://api.niaid.nih.gov/{api-name}/v{version}/{resource}`

**Example**:
```
https://api.niaid.nih.gov/crms-api/v1/protocols
https://api.niaid.nih.gov/crms-api/v2/protocols
```

**Pros**:
- ✅ Most visible and explicit
- ✅ Easy to route and cache
- ✅ Clear for consumers to understand
- ✅ Works well with GitOps (separate folders per version)
- ✅ Industry standard (used by GitHub, Stripe, Twilio)

**Cons**:
- ❌ Requires URL path changes
- ❌ Slightly longer URLs

**GitOps Structure**:
```
apimartifacts/
  apis/
    crms-api-v1/
      apiInformation.json
      specification.yaml
      operations/
    crms-api-v2/
      apiInformation.json
      specification.yaml
      operations/
  version sets/
    crms-api-version-set/
      versionSetInformation.json
```

---

### 2. Header-Based Versioning

**Format**: `api-version: 2.0` (in HTTP header)

**Example**:
```http
GET https://api.niaid.nih.gov/crms-api/protocols
api-version: 2.0
```

**Pros**:
- ✅ Clean URLs (no version in path)
- ✅ Good for internal/enterprise APIs

**Cons**:
- ❌ Not visible in browser/simple tools
- ❌ Harder to discover available versions
- ❌ Caching challenges
- ❌ More complex to test

**Use Case**: Internal microservices, backend APIs

---

### 3. Query Parameter Versioning

**Format**: `?api-version=2.0`

**Example**:
```
https://api.niaid.nih.gov/crms-api/protocols?api-version=2.0
```

**Pros**:
- ✅ Base URL remains clean
- ✅ Easy to implement

**Cons**:
- ❌ Query parameters meant for filtering, not versioning
- ❌ Can conflict with actual query params
- ❌ Less visible than path-based

**Use Case**: Azure-style services (ARM, Azure AD)

---

## Recommended Strategy

### Primary Approach: URL Path (Segment) Versioning

**Why**: Best fit for NIAID's mixed internal/external API consumers, clear for documentation, GitOps-friendly.

### Version Set Configuration

```json
{
  "properties": {
    "displayName": "CRMS API",
    "versioningScheme": "Segment",
    "description": "Clinical Research Management System API"
  }
}
```

### API Version Configuration

```json
{
  "properties": {
    "path": "crms-api",
    "apiVersion": "v1",
    "apiVersionSetId": "/subscriptions/.../apiVersionSets/crms-api-version-set",
    "displayName": "CRMS API v1",
    "protocols": ["https"],
    "isCurrent": true
  }
}
```

### Semantic Versioning Scheme

- **Major Versions**: `v1`, `v2`, `v3` (breaking changes)
- **Minor Changes**: Use Revisions (non-breaking)
- **Patches**: Backend changes only (no API contract change)

---

## Implementation Guidelines

### 1. When to Create a New Version

**Create a new major version (v1 → v2) when**:
- Removing or renaming endpoints
- Changing request/response schemas (breaking changes)
- Changing authentication requirements
- Removing required parameters
- Changing data types (string → integer)
- Changing error response formats

**Use Revisions (v1.1, v1.2) when**:
- Adding new optional parameters
- Adding new endpoints
- Adding new response fields (backwards compatible)
- Fixing bugs without changing contract
- Improving performance
- Updating documentation

**Backend-only changes (no version bump)**:
- Internal implementation changes
- Database optimizations
- Logging improvements
- Performance tuning

---

### 2. Creating a New API Version

#### Step 1: Create Version Set (First Time Only)

```bash
# Azure Portal or via ARM template
az rest --method put \
  --uri "https://management.azure.com/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.ApiManagement/service/{apim}/apiVersionSets/{version-set-name}?api-version=2022-08-01" \
  --body '{
    "properties": {
      "displayName": "CRMS API",
      "versioningScheme": "Segment",
      "description": "Clinical Research Management System API"
    }
  }'
```

#### Step 2: Extract Current Version Set

```bash
# Run extractor to capture version set in repository
./tools/code/extractor/APIExtractor run \
  --AZURE_SUBSCRIPTION_ID $AZURE_SUBSCRIPTION_ID \
  --API_MANAGEMENT_SERVICE_NAME apim-daids-connect \
  --RESOURCE_GROUP_NAME nih-niaid-avidpoc-dev-rg \
  --API_MANAGEMENT_SERVICE_OUTPUT_FOLDER_PATH ./apimartifacts
```

**Result**:
```
apimartifacts/
  version sets/
    crms-api-version-set/
      versionSetInformation.json
```

#### Step 3: Create New Version in Portal/Code

**Option A: Azure Portal**
1. Navigate to APIM → APIs → Select API
2. Click "Add version"
3. Versioning scheme: "URL path segment"
4. Version identifier: `v2`
5. Full API path: `crms-api/v2`

**Option B: GitOps (Recommended)**
1. Copy existing API folder: `crms-api-v1` → `crms-api-v2`
2. Update `apiInformation.json`:
   ```json
   {
     "properties": {
       "path": "crms-api",
       "apiVersion": "v2",
       "apiVersionSetId": "/subscriptions/.../apiVersionSets/crms-api-version-set",
       "displayName": "CRMS API v2",
       "isCurrent": true
     }
   }
   ```
3. Update OpenAPI spec (`specification.yaml`)
4. Update policies as needed
5. Commit and push
6. Publisher workflow deploys new version

#### Step 4: Update v1 to Mark as Non-Current

```json
{
  "properties": {
    "isCurrent": false  // v1 is now legacy
  }
}
```

---

### 3. Migration Path for Existing APIs

**Unversioned APIs** (e.g., `/opentext`) have two options:

#### Option A: Add Version to Existing Path (Breaking Change)
- Current: `https://api.niaid.nih.gov/opentext/nodes`
- New: `https://api.niaid.nih.gov/opentext/v1/nodes`
- **Impact**: ⚠️ Breaks existing consumers
- **When**: No active consumers OR coordinated migration

#### Option B: Treat Current as v1 (Recommended)
- Current (implicit v1): `https://api.niaid.nih.gov/opentext/nodes`
- New v2: `https://api.niaid.nih.gov/opentext/v2/nodes`
- **Impact**: ✅ No breaking changes
- **When**: Active consumers exist

**Recommended Approach for NIAID**:
```json
// Version Set
{
  "properties": {
    "displayName": "OpenText EDRMS API",
    "versioningScheme": "Segment"
  }
}

// Existing API (becomes implicit v1)
{
  "properties": {
    "path": "opentext",
    "apiVersionSetId": ".../opentext-version-set",
    "displayName": "OpenText EDRMS API (Legacy)",
    "isCurrent": false  // Mark as legacy
  }
}

// New v2
{
  "properties": {
    "path": "opentext",
    "apiVersion": "v2",
    "apiVersionSetId": ".../opentext-version-set",
    "displayName": "OpenText EDRMS API v2",
    "isCurrent": true
  }
}
```

**Consumer Experience**:
- Legacy consumers: Continue using `https://api.niaid.nih.gov/opentext/nodes`
- New consumers: Use `https://api.niaid.nih.gov/opentext/v2/nodes`
- Both work simultaneously

---

## GitOps Workflow Integration

### Repository Structure

```
apimartifacts/
  apis/
    crms-api-v1/              # Version 1
      apiInformation.json
      specification.yaml
      policy.xml
      operations/
    crms-api-v2/              # Version 2
      apiInformation.json
      specification.yaml
      policy.xml
      operations/
    opentext/                 # Legacy (implicit v1)
      apiInformation.json
      specification.yaml
    opentext-v2/              # Explicit v2
      apiInformation.json
      specification.yaml
  version sets/
    crms-api-version-set/
      versionSetInformation.json
    opentext-version-set/
      versionSetInformation.json
```

### Deployment Workflow

1. **Developer** creates new version folder (e.g., `crms-api-v2`)
2. **Commit** changes to feature branch
3. **Extractor** runs on DAIDS_DEV to capture current state
4. **Publisher** deploys to DEV → QA → PROD
5. **Testing** validates both v1 and v2 simultaneously
6. **Consumers** migrate at their own pace

### Configuration Files

**No special configuration needed** - Version sets and API versions deploy like any other artifact.

```yaml
# configuration.dev.yaml
# No version-specific settings required

# Publisher handles version sets automatically
```

---

## Backwards Compatibility

### Backwards-Compatible Changes (Use Revisions)

- ✅ Adding new optional request parameters
- ✅ Adding new response fields
- ✅ Adding new endpoints
- ✅ Making required parameters optional
- ✅ Relaxing validation rules
- ✅ Adding new enum values (if clients handle unknowns gracefully)

### Breaking Changes (Require New Major Version)

- ❌ Removing endpoints
- ❌ Removing request parameters
- ❌ Removing response fields
- ❌ Renaming fields
- ❌ Changing field types
- ❌ Changing error formats
- ❌ Changing authentication mechanisms
- ❌ Making optional parameters required
- ❌ Changing URL paths

### Testing for Compatibility

**Automated Contract Testing** (Recommended):

```yaml
# .github/workflows/api-contract-test.yaml
name: API Contract Testing

on:
  pull_request:
    paths:
      - 'apimartifacts/apis/*/specification.yaml'

jobs:
  contract-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Detect Breaking Changes
        run: |
          # Compare OpenAPI specs between versions
          npx @openapitools/openapi-diff \
            apimartifacts/apis/crms-api-v1/specification.yaml \
            apimartifacts/apis/crms-api-v2/specification.yaml
      
      - name: Comment on PR
        if: failure()
        run: |
          echo "⚠️ Breaking changes detected! Major version bump required."
```

---

## Version Lifecycle Management

### Version States

```
[New] → [Current] → [Deprecated] → [Retired]
  ↓         ↓            ↓             ↓
Active   Active    Limited Support  Removed
```

### Lifecycle Stages

| Stage | Description | Support Level | Timeline |
|-------|-------------|---------------|----------|
| **New** | Recently released, testing phase | Full support, closely monitored | 0-3 months |
| **Current** | Stable, recommended version | Full support, SLA applies | Ongoing |
| **Deprecated** | Marked for removal, discouraged | Bug fixes only, no new features | 6-12 months |
| **Retired** | Removed from service | None - returns 410 Gone | - |

### Deprecation Policy

**Minimum Notice Period**: 6 months before retirement

**Deprecation Steps**:

1. **Announcement (T-6 months)**
   - Update API documentation
   - Add deprecation headers to responses
   - Email active consumers
   - Post to developer portal

2. **Warning Headers (T-6 to T-0)**
   ```http
   Deprecation: true
   Sunset: Sat, 31 Dec 2026 23:59:59 GMT
   Link: <https://developer.niaid.nih.gov/crms-api/v2>; rel="successor-version"
   ```

3. **Mark as Non-Current (T-3 months)**
   ```json
   {
     "properties": {
       "isCurrent": false
     }
   }
   ```

4. **Retirement (T-0)**
   - Remove API from APIM
   - Return 410 Gone for legacy endpoints
   - Redirect documentation to new version

### Deprecation Policy Implementation

**APIM Policy for Deprecated APIs**:

```xml
<policies>
    <inbound>
        <base />
        <!-- Add deprecation headers -->
        <set-header name="Deprecation" exists-action="override">
            <value>true</value>
        </set-header>
        <set-header name="Sunset" exists-action="override">
            <value>Sat, 31 Dec 2026 23:59:59 GMT</value>
        </set-header>
        <set-header name="Link" exists-action="override">
            <value>&lt;https://developer.niaid.nih.gov/crms-api/v2&gt;; rel="successor-version"</value>
        </set-header>
        <!-- Log deprecation usage -->
        <log-to-eventhub logger-id="eventhub-logger">
            @{
                return new {
                    EventType = "DeprecatedAPIUsage",
                    API = "crms-api-v1",
                    Consumer = context.Subscription?.Name,
                    Timestamp = DateTime.UtcNow
                }.ToString();
            }
        </log-to-eventhub>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

### Version Concurrency Rules

**Maximum Active Versions**: 2 major versions simultaneously

**Example Timeline**:
```
Jan 2026: v1 (Current), v2 (New)
Jul 2026: v1 (Deprecated), v2 (Current), v3 (New)
Jan 2027: v1 (Retired), v2 (Current), v3 (Current)
```

**Exception**: Allow 3 versions temporarily during major migrations (max 3 months overlap).

---

## Consumer Communication

### Communication Channels

1. **API Developer Portal** (Primary)
   - Publish version roadmap
   - Document deprecation timelines
   - Provide migration guides

2. **Email Notifications**
   - Target: Active API consumers (via subscription data)
   - Frequency: T-6mo, T-3mo, T-1mo, T-1wk

3. **HTTP Response Headers** (Automatic)
   - `Deprecation: true`
   - `Sunset: <date>`
   - `Link: <successor>; rel="successor-version"`

4. **GitHub Repository** (For internal teams)
   - CHANGELOG.md per API
   - Migration guides
   - Breaking change notices

### Documentation Requirements

**For Each Version**:
- ✅ OpenAPI specification
- ✅ Migration guide (for breaking changes)
- ✅ Changelog
- ✅ Deprecation timeline (if applicable)
- ✅ Code samples for common scenarios

**CHANGELOG.md Example**:

```markdown
# CRMS API Changelog

## v2.0.0 (2026-01-15) - CURRENT

### Breaking Changes
- Removed `/v1/protocols` endpoint (use `/v2/studies` instead)
- Changed `date` fields from string to ISO 8601 format
- Renamed `protocolId` to `studyId` for consistency

### New Features
- Added `/studies/{id}/investigators` endpoint
- Support for bulk operations via `/studies/batch`
- Enhanced filtering with OData query syntax

### Migration Guide
See [CRMS-API-v1-to-v2-Migration.md](./CRMS-API-v1-to-v2-Migration.md)

## v1.0.0 (2025-06-01) - DEPRECATED
**Deprecation Date**: 2026-01-15  
**Sunset Date**: 2026-07-15

### Features
- Protocol search and retrieval
- Site management
- Staff lookup
```

---

## Testing Strategy

### Multi-Version Testing

**Test Both Versions Simultaneously**:

```yaml
# .github/workflows/test-apis-ephemeral.yaml
jobs:
  test-api-versions:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        api: [crms-api]
        version: [v1, v2]
    steps:
      - name: Test API ${{ matrix.api }} ${{ matrix.version }}
        run: |
          newman run tests/${{ matrix.api }}-${{ matrix.version }}.postman_collection.json \
            --environment tests/${{ inputs.ENVIRONMENT }}.postman_environment.json
```

### Contract Testing

**OpenAPI Validation**:

```bash
# Validate spec compliance
spectral lint apimartifacts/apis/crms-api-v2/specification.yaml

# Compare versions for breaking changes
openapi-diff \
  apimartifacts/apis/crms-api-v1/specification.yaml \
  apimartifacts/apis/crms-api-v2/specification.yaml
```

### Backward Compatibility Testing

**Postman Collection Strategy**:

```
tests/
  crms-api-v1.postman_collection.json      # v1 tests (regression)
  crms-api-v2.postman_collection.json      # v2 tests (new features)
  crms-api-compatibility.postman_collection.json  # Cross-version tests
```

**Compatibility Test Scenarios**:
1. v1 consumers should NOT be affected by v2 deployment
2. v2 adds features WITHOUT removing v1 functionality
3. Shared resources (backends, databases) work for both versions
4. Authentication works across versions

---

## Recommendations for NIAID APIs

### Immediate Actions (This Quarter)

| API | Current State | Recommended Action | Priority |
|-----|---------------|-------------------|----------|
| **Merlin Vendor Lookup** | ✅ Already versioned (v1 + legacy) | Deprecate legacy version, keep v1 only | Medium |
| **CRMS-API-QA** | ❌ No versioning | Add version set, treat current as implicit v1 | High |
| **OpenText EDRMS** | ❌ No versioning | Add version set, plan v2 with breaking changes | Medium |
| **OTCS MCP Server** | ❌ No versioning | Add version set if API is stable | Low |
| **Merlin DB** | ❌ No versioning | Add version set if API is stable | Low |

### Long-Term Strategy (Next 12 Months)

1. **Q1 2026**: Establish version sets for all production APIs
2. **Q2 2026**: Document current APIs as implicit v1, publish migration guides
3. **Q3 2026**: Release v2 for APIs with breaking changes needed
4. **Q4 2026**: Deprecate legacy versions, publish sunset timelines

### Quick Start: Add Versioning to CRMS API

**Step 1: Create Version Set in Portal**
```bash
# In Azure Portal: APIM → APIs → Version sets → Add
Display Name: CRMS API
Versioning Scheme: URL path segment
```

**Step 2: Update Existing API (becomes implicit v1)**
```bash
# In Portal: CRMS-API-QA → Settings → Version
Associate with version set: CRMS API
Version identifier: (leave blank for legacy)
```

**Step 3: Extract to Repository**
```bash
gh workflow run run-extractor.yaml -f ENVIRONMENT=daids_dev
```

**Step 4: Plan v2** (when breaking changes needed)
- Copy `crms-api-qa` folder to `crms-api-v2`
- Update `apiInformation.json` with `"apiVersion": "v2"`
- Update OpenAPI spec
- Deploy via publisher workflow

---

## References

- [Azure APIM Versioning Documentation](https://learn.microsoft.com/en-us/azure/api-management/api-management-versions)
- [Azure APIM Revisions](https://learn.microsoft.com/en-us/azure/api-management/api-management-revisions)
- [Semantic Versioning](https://semver.org/)
- [HTTP Deprecation Header RFC](https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-deprecation-header)
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)

---

## Change Log

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-01-06 | 1.0 | GitHub Copilot | Initial strategy document |

---

## Approval

**Document Status**: ✅ Draft for Review

**Next Steps**:
1. Review with NIAID API stakeholders
2. Validate against consumer requirements
3. Pilot with one API (recommended: CRMS-API-QA)
4. Incorporate feedback and finalize
5. Publish to team wiki/SharePoint

