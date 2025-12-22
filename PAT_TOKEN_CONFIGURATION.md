# PAT Token Configuration Guide

## Overview

This pipeline uses **separate PAT tokens** for different stages to follow the principle of least privilege and security best practices.

## Variable Groups

### 1. `core-entauto-github-migration-secrets`

**Purpose:** Migration, validation, and rewiring operations

**Variables:**
- `GH_TOKEN` - GitHub Personal Access Token
- `ADO_PAT` - Azure DevOps Personal Access Token

**Required Scopes:**

**GH_TOKEN (GitHub):**
- `repo` - Full control of private repositories
- `admin:org` - Read org and team membership
- `workflow` - Update GitHub Actions workflows

**ADO_PAT (Azure DevOps):**
- Code (Read, Write)
- Build (Read & Execute)
- Project and Team (Read)
- Service Connections (Read, Query, Manage)

**Used in Stages:**
- prereq Validation
- active pr & pipeline check
- repo migration
- repo migration validation
- pipeline rewiring

---

### 2. `azure-boards-integration-secrets`

**Purpose:** Azure Boards integration with GitHub (SEPARATE from migration)

**Variables:**
- `GH_PAT` - GitHub Personal Access Token for Boards integration
- `ADO_PAT` - Azure DevOps PAT specifically for Boards integration (DIFFERENT token than migration ADO_PAT)

**Required Scopes:**

**GH_PAT (GitHub PAT):**
- `repo` - Full control of private repositories
- `admin:org` - Read org and team membership

**ADO_PAT (Azure DevOps PAT - Boards Only):**
- Code (Read only)
- Work Items (Read, Write)
- Project and Team (Read)

**Used in Stages:**
- Azure Boards Integration (Stage 6)

**IMPORTANT:** This ADO_PAT is a **separate token** from the migration ADO_PAT with limited Boards-only scopes.

---

## Security Separation

### Why Separate PAT Tokens?

1. **Principle of Least Privilege**: Each PAT has only the minimum required permissions
2. **Audit Trail**: Different tokens make it easier to track which operations used which credentials
3. **Security Isolation**: If one token is compromised, it limits the blast radius
4. **Compliance**: Meets security best practices for credential management

### Token Isolation Rules

❌ **NEVER** use `ADO_PAT` in the Azure Boards Integration stage
❌ **NEVER** use `AZURE_BOARDS_PAT` in migration/validation/rewiring stages
✅ **ALWAYS** use the appropriate token for each stage's purpose
✅ **ALWAYS** rotate tokens separately and independently

---

## Setup Instructions

### Step 1: Create Variable Groups in Azure DevOps

#### Create Migration Secrets Group

1. Go to **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name: `core-entauto-github-migration-secrets`
4. Add variables:
   - Name: `GH_TOKEN`, Value: `<your-github-token>`, **Lock** (secret)
   - Name: `ADO_PAT`, Value: `<your-ado-token>`, **Lock** (secret)
5. Click **Save**

#### Create Boards Integration Secrets Group

1. Go to **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name: `azure-boards-integration-secrets`
4. Add variables:
   - Name: `GH_PAT`, Value: `<your-github-token>`, **Lock** (secret)
   - Name: `ADO_PAT`, Value: `<your-boards-specific-ado-token>`, **Lock** (secret)
5. Click **Save**

**Note:** The `ADO_PAT` in this group is a **different token** with different scopes than the `ADO_PAT` in `core-entauto-github-migration-secrets`.

### Step 2: Create PAT Tokens

#### GitHub PAT Creation

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click **Generate new token (classic)**
3. Name: `ADO to GHE Migration Token`
4. Select scopes: `repo`, `admin:org`, `workflow`
5. Click **Generate token**
6. **Copy the token immediately** and save it in both variable groups

#### Azure DevOps Migration PAT Creation

1. Go to Azure DevOps → User Settings → Personal access tokens
2. Click **+ New Token**
3. Name: `ADO to GHE Migration PAT`
4. Scopes: Code (Read, Write), Build (Read & Execute), Project and Team (Read), Service Connections (Read, Query, Manage)
5. Click **Create**
6. **Copy the token** and save it as `ADO_PAT` in `core-entauto-github-migration-secrets`

#### Azure DevOps Boards PAT Creation (SEPARATE TOKEN)

1. Go to Azure DevOps → User Settings → Personal access tokens
2. Click **+ New Token**
3. Name: `Azure Boards Integration PAT`
4. Scopes: Code (Read only), Work Items (Read, Write), Project and Team (Read)
5. Click **Create**
6. **Copy the token** and save it as `ADO_PAT` in `azure-boards-integration-secrets`

**CRITICAL:** This is a **different PAT token** than the migration ADO_PAT. Do not reuse the migration token.

### Step 3: Verify Pipeline Permissions

1. Go to **Pipelines** → Select your pipeline
2. Click **Edit** → **⋮** → **Settings**
3. Under **Variable groups**, verify both groups are accessible

---

## Token Rotation Schedule

- **Recommended**: Rotate all PAT tokens every 90 days
- **Required**: Rotate immediately if token is suspected to be compromised
- **Best Practice**: Use different expiration dates for each token type

---

## Troubleshooting

### Error: "AZURE_BOARDS_PAT environment variable is not set" or "ADO_PAT not set"

**Solution:** Ensure the `azure-boards-integration-secrets` variable group exists and contains `ADO_PAT` with Boards-only scopes

### Error: "Permission denied" during migration

**Solution:** Verify `ADO_PAT` has the correct scopes (Code, Build, Project and Team, Service Connections)

### Error: "Work item access denied" during Boards integration

**Solution:** Verify the `ADO_PAT` in `azure-boards-integration-secrets` has Work Items (Read, Write) scope

---

## Stage-to-Token Mapping

| Stage | Variable Group | PAT Tokens Used |
|-------|---------------|----------------|
| prereq Validation | core-entauto-github-migration-secrets | - |
| active pr & pipeline check | core-entauto-github-migration-secrets | GH_TOKEN, ADO_PAT |
| repo migration | core-entauto-github-migration-secrets | GH_TOKEN, ADO_PAT |
| repo migration validation | core-entauto-github-migration-secrets | GH_TOKEN, ADO_PAT |
| pipeline rewiring | core-entauto-github-migration-secrets | GH_TOKEN, ADO_PAT |
| **Azure Boards Integration** | **azure-boards-integration-secrets** | **GH_PAT, ADO_PAT (Boards-only scopes)** |

---

## Security Checklist

- [ ] Created separate variable groups for migration and Boards integration
- [ ] Created separate Azure DevOps PAT for Boards integration
- [ ] Verified Boards PAT has limited scopes (Code Read, Work Items, Project/Team)
- [ ] Verified migration PAT is NOT used in Boards integration stage
- [ ] All PAT tokens are marked as secret (locked) in variable groups
- [ ] Documented token rotation schedule
- [ ] Tested pipeline with both variable groups
- [ ] Pipeline stages clearly document which tokens they use

---

*Last Updated: December 22, 2025*
