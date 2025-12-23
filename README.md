# 🚀 ADO to GitHub Migration Pipeline

Migrating repositories from Azure DevOps (ADO) to GitHub Enterprise (GHE) using a hybrid approach is inherently challenging due to the multiple stages involved in the end-to-end process. This includes prerequisite checks such as installing the GitHub CLI and the ado2gh extension, authenticating with GitHub, and performing pre-migration validations (for example, identifying in-flight pull requests or running pipelines that could be missed during migration). It then proceeds through the actual repository migration, post-migration validation, ADO pipeline rewiring, Azure Boards integration, and finally disabling the ADO repository to prevent further developer usage after a successful migration.

Even with automation scripts, this process can be cumbersome and difficult to scale, especially for organizations managing tens of thousands of repositories. I encountered a scenario where an organization needed to migrate nearly 20,000 repositories, making it impractical to rely solely on scripts to execute both migration and post-migration steps in a centralized manner.

To address this scalability challenge, I designed a stage-based Azure DevOps YAML pipeline that encapsulates the entire migration lifecycle from prerequisite validation through successful migration, post-migration rewiring, Azure Boards integration, and safe decommissioning of the ADO repository. This pipeline enables a decentralized, self-service migration model, where individual teams can independently migrate only the repositories they own.

By distributing ownership to teams and allowing migrations to run in parallel, this approach scales effectively for large enterprises, avoids centralized bottlenecks and big-bang migrations, and makes the overall ADO-to-GHE migration process more manageable, controlled, and resilient.

## What This Pipeline Does

The **ADO to GitHub Migration Pipeline** automates the complete migration process from Azure DevOps repositories to GitHub in six sequential stages with three manual approval gates:

### Stage 1: Prerequisite Validation
- Verifies that `bash/repos.csv` file exists and is not empty
- Validates that the CSV contains all required columns:
  - `org`, `teamproject`, `repo`
  - `github_org`, `github_repo`, `gh_repo_visibility`
- Displays the number of repositories to be migrated

### Stage 2: Active PR & Pipeline Check (Manual Approval Required)
Executes `1_migration_readiness_check.sh` to:

- Scans source repositories for active pull requests
- Checks for running builds and releases
- Identifies potential blockers before migration begins
- Generates a readiness report
- **⏸️ Manual Approval Gate:** Review readiness before proceeding to migration

### Stage 3: Repo Migration
Executes `2_migration.sh` to perform the actual migration:

- Installs GitHub CLI and `gh-ado2gh` extension
- Executes parallel migrations (configurable: 1-5 concurrent migrations)
- Migrates repository content, branches, and commit history
- Generates migration status logs for each repository
- Creates a summary CSV with migration results

### Stage 4: Repo Migration Validation (Manual Approval Required)
Executes `3_post_migration_validation.sh` to:

- Validates each migrated repository in GitHub
- Compares branches between source (ADO) and target (GitHub)
- Verifies repository accessibility and structure
- Generates validation logs with detailed results
- **⏸️ Manual Approval Gate:** Review validation before rewiring pipelines

### Stage 5: Pipeline Rewiring
Executes `4_rewire_pipeline.sh` to:

- Reads pipeline configurations from `bash/pipelines.csv`
- Rewires Azure DevOps pipelines to use GitHub repositories
- Updates service connections and repository sources
- Validates pipeline configurations
- Generates rewiring logs

### Stage 6: Azure Boards Integration (Manual Approval Required)
- **⏸️ Manual Approval Gate:** Review rewiring before Boards integration
Executes `5_azure_boards_integration.sh` to:

- Validates GitHub service connections via ADO REST API
- Integrates Azure Boards with migrated GitHub repositories
- Enables AB# work item linking in GitHub commits/PRs
- Configures bidirectional synchronization
- Uses separate Boards-only PAT token for security isolation

## ⚙️ Prerequisites

Before running this pipeline, ensure the following requirements are met:

### 1. Variable Group Configuration ⚠️ MANDATORY

This pipeline requires **TWO separate variable groups** for security isolation:

#### A. Migration Variable Group: `core-entauto-github-migration-secrets`

Used in Stages 1-5 (Validation, Readiness, Migration, Validation, Rewiring)

| Variable Name | Description | Required |
|--------------|-------------|----------|
| `GH_PAT` | GitHub Personal Access Token with `admin:org`, `read:user`, `repo`, `workflow` scopes | ✅ Yes |  
| `ADO_PAT` | Azure DevOps PAT with Code (Read, Write), Build, Service Connections scopes | ✅ Yes |

#### B. Boards Integration Variable Group: `azure-boards-integration-secrets`

Used in Stage 6 (Azure Boards Integration) - **SEPARATE token with limited scopes**

| Variable Name | Description | Required |
|--------------|-------------|----------|
| `GH_PAT` | GitHub Personal Access Token with `repo`, `admin:org` scopes | ✅ Yes |  
| `ADO_PAT` | Azure DevOps PAT with Code (Read only), Work Items (Read, Write), Project/Team (Read) - **DIFFERENT from migration ADO_PAT** | ✅ Yes |

> **🔒 SECURITY NOTE**: The `ADO_PAT` in each variable group is a **different token** with different scopes. This follows the principle of least privilege. See [PAT_TOKEN_CONFIGURATION.md](PAT_TOKEN_CONFIGURATION.md) for detailed setup instructions.

> **⚠️ IMPORTANT**: Both variable groups are **mandatory**. The pipeline will fail if they don't exist. Create them before running the pipeline for the first time.

**Step-by-step instructions to create variable groups:**

1. **Navigate to Library in Azure DevOps:**
   - Open your browser and go to: `https://dev.azure.com/<org>/<project>/_library`
   - Or navigate manually: Click **Pipelines** in the left menu → Click **Library**

2. **Create the first variable group (Migration):**
   - Click the **+ Variable group** button at the top
   - **Variable group name**: Enter `core-entauto-github-migration-secrets` (must match exactly)
   - **Description**: "Migration PAT tokens for ADO to GitHub migration (Stages 1-5)"
   - Click **+ Add** to add `GH_PAT` → paste token → click 🔒 to mark as secret
   - Click **+ Add** to add `ADO_PAT` → paste migration token → click 🔒 to mark as secret
   - Click **Save**

3. **Create the second variable group (Boards Integration):**
   - Click the **+ Variable group** button again
   - **Variable group name**: Enter `azure-boards-integration-secrets` (must match exactly)
   - **Description**: "Boards-only PAT tokens for Azure Boards integration (Stage 6)"
   - Click **+ Add** to add `GH_PAT` → paste token → click 🔒 to mark as secret
   - Click **+ Add** to add `ADO_PAT` → paste Boards-only token → click 🔒 to mark as secret
   - Click **Save**

> **📖 Detailed Token Setup**: For complete instructions on creating separate PAT tokens with correct scopes, see [PAT_TOKEN_CONFIGURATION.md](PAT_TOKEN_CONFIGURATION.md)

6. **Set permissions (if needed):**
   - Click **Pipeline permissions** tab
   - If the pipeline isn't automatically authorized, click **+** and add "ADO to GitHub Migration Pipeline"
   - This allows the pipeline to access the variable group

7. **Save the variable group:**
   - Click **Save** at the top
  
After creating the variable group, you should see:
- Variable group name: `core-entauto-github-migration-secrets`
- 2 variables: `GH_TOKEN` (**secret**), `ADO_PAT` (**secret**)
- Both variables should show 🔒 (locked) indicating they are secret

### 2. GitHub Personal Access Token (PAT)
Create a GitHub PAT with the following scopes:
- `read:user` (Read ALL user profile data)
- `admin:org` (Full control of orgs and teams, read and write org projects)
- `repo` (Full control of private repositories)
- `workflow` (Update GitHub Action workflows)

**To create:**
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click **Generate new token (classic)**
3. Select the required scopes
4. Copy the token (you won't see it again!)

### 3. Azure DevOps Personal Access Token (PAT)
Create an ADO PAT with **Full access** scope:
1. Go to Azure DevOps → User settings → Personal access tokens
2. Click **+ New Token**
3. Set expiration and select **Full access**
4. Copy the token

### 4. Repository CSV File
The `bash/repos.csv` file must exist with the following structure:

```csv
org,teamproject,repo,url,last-push-date,pipeline-count,compressed-repo-size-in-bytes,most-active-contributor,pr-count,commits-past-year,github_org,github_repo,gh_repo_visibility
contosodevopstest,sample-repo-testing,sample1,https://dev.azure.com/contosodevopstest/sample-repo-testing/_git/sample1,10/13/2025 0:00,5,"9,349",System Administrator (admin@example.com),0,9,ADO2GH-Migration,sample1,private
```

**Required columns:**
- `org` - Azure DevOps organization name
- `teamproject` - Azure DevOps project name
- `repo` - Azure DevOps repository name
- `github_org` - Target GitHub organization
- `github_repo` - Target GitHub repository name
- `gh_repo_visibility` - Repository visibility: `private`, `public`, or `internal`

### 5. Pipeline CSV File (Required for Stage 5)
The `bash/pipelines.csv` file must exist with the following structure for pipeline rewiring:

```csv
org,teamproject,repo,pipeline,url,serviceConnection,github_org,github_repo
contosodevopstest,sample-repo-testing,sample1,\sample1-ci,https://dev.azure.com/contosodevopstest/sample-repo-testing/_build?definitionId=24,e2b1070b-277f-4e60-8bdb-8bb3b5ac122a,ADO2GH-Migration,sample1
```

**Required columns:**
- `org` - Azure DevOps organization name
- `teamproject` - Azure DevOps project name
- `pipeline` - Pipeline name/path to rewire
- `github_org` - Target GitHub organization
- `github_repo` - Target GitHub repository name
- `serviceConnection` - Azure DevOps GitHub service connection ID

## How to Update repos.csv and Run the Pipeline

### 🛠 Updating repos.csv

1. **Edit the CSV file from you local:**
   ```bash
   # Navigate to the local dir
   cd c:\Users\<username>\factory\ado2gh-ado-pipelines
   
   # Edit the CSV file
   code bash/repos.csv
   ```

2. **Add or modify repository entries:**
   - Each row represents one repository to migrate
   - Ensure all required columns have values
   - Use proper CSV formatting (quote fields with commas)
   - Verify `gh_repo_visibility` is one of: `private`, `public`, `internal`

3. **Commit and push changes:**
   ```bash
   git add bash/repos.csv
   git commit -m "Update repos.csv with new repositories"
   git push
   ```

### ▶️ Running the Pipeline

#### Option 1: Via Azure DevOps Web UI
1. Navigate to: https://dev.azure.com/<org>/<project>/_build
2. Click on **ADO to GitHub Migration Pipeline**
3. Click **Run pipeline** button
4. Select branch: `main`
5. Click **Run**

#### Option 2: Via Azure CLI
```bash
# Run the pipeline
az pipelines run --name "ADO to GitHub Migration Pipeline" \
  --branch main \
  --project ado2gh-ado-pipelines \
  --organization https://dev.azure.com/<org>
```

#### Option 3: Programmatically (PowerShell)
```powershell
# Trigger pipeline run
az pipelines run --id 32 --project ado2gh-ado-pipelines --organization https://dev.azure.com/contosodevopstest
```

### Configuring Concurrent Migrations

You can adjust the number of concurrent migrations by modifying the `maxConcurrent` variable in `ado2gh-migration.yml`:

```yaml
variables:
  - group: core-entauto-github-migration-secrets
  - name: maxConcurrent
    value: 3  # Change this value (1-5)
```

## 📄 Pipeline Run Logs

### Accessing Pipeline Logs

#### 1. View Logs in Azure DevOps UI
1. Navigate to the pipeline run: https://dev.azure.com/<org>/<project>/_build
2. Click on the specific build number (e.g., `20251208.5`)
3. Click on any stage or job to view logs
4. Use the **Download logs** button to save all logs as a ZIP file

#### 2. Published Artifacts
The pipeline publishes detailed logs as build artifacts:

**Migration Logs** (from Stage 3: Migration)
- **Artifact Name**: `migration-logs`
- **Contains**:
  - Individual migration log files for each repository
  - Migration output CSV with status for each repository
  - Timestamped log files

**Validation Logs** (from Stage 4: Post-Migration Validation)
- **Artifact Name**: `validation-logs`
- **Contains**:
  - Validation log files for each repository
  - JSON files with repository details
  - Branch comparison results
  - Timestamped validation logs

**To download artifacts:**
1. Go to the completed pipeline run
2. Click on the **Summary** or **Published** tab
3. Find the **Artifacts** section
4. Click on **migration-logs** or **validation-logs** to download

#### 3. 🧭 Log Files Location in Artifacts

After downloading and extracting the artifacts, you'll find:

```
migration-logs/
├── repo_migration_output-YYYYMMDD-HHMMSS.csv    # Migration status summary
├── migration-<repo-name>.log                     # Individual repo logs
└── s/                                            # Full workspace snapshot
    └── bash/
        └── repos.csv

validation-logs/
├── validation-log-YYYYMMDD.txt                   # Validation summary
├── validation-<repo-name>.json                   # GitHub repo details
└── s/                                            # Full workspace snapshot
```

#### 4. Interpreting Log Files

**Migration Status CSV:**
```csv
org,teamproject,repo,github_org,github_repo,gh_repo_visibility,Migration_Status,Log_File
contosodevopstest,sample-repo-testing,sample1,ADO2GH-Migration,sample1,private,Success,migration-sample1.log
```

**Status Values:**
- `Success` - Repository migrated successfully
- `Failure` - Migration failed, check log file for details
- `Pending` - Migration in progress or queued

**Individual Log Files:**
Each log file contains:
- Timestamp of migration start
- GitHub CLI command executed
- Detailed migration output from `gh-ado2gh`
- Success or failure indicators
- Error messages (if any)

### ❌ Troubleshooting Failed Migrations

If a migration fails:

1. **Check the individual log file** in `migration-logs` artifact
2. **Common issues:**
   - Repository already exists in GitHub
   - Insufficient permissions (check PAT scopes)
   - Network timeouts (consider reducing concurrent migrations)
   - Invalid repository names or visibility settings

3. **Retry failed repositories:**
   - Remove successful entries from `repos.csv`
   - Keep only failed repositories
   - Commit and push changes
   - Trigger a new pipeline run

## 📂 Pipeline Structure

```
ado2gh-ado-pipelines/
├── ado2gh-migration.yml                          # Main pipeline definition (6 stages)
├── bash/
│   ├── 1_migration_readiness_check.sh           # Stage 2: Readiness validation script
│   ├── 2_migration.sh                           # Stage 3: Migration execution script
│   ├── 3_post_migration_validation.sh           # Stage 4: Post-migration validation script
│   ├── 4_rewire_pipeline.sh                     # Stage 5: Pipeline rewiring script
│   ├── 5_azure_boards_integration.sh            # Stage 6: Azure Boards integration script
│   ├── repos.csv                                # Repository list (required)
│   └── pipelines.csv                            # Pipeline list for rewiring (required for Stage 5)
├── PAT_TOKEN_CONFIGURATION.md                    # Detailed PAT token setup guide
├── .gitattributes                                # Git line ending configuration
└── README.md                                     # This file
```

## ⭐ Key Features

✅ **6-Stage Migration Process**: Complete end-to-end migration with validation gates
✅ **3 Manual Approval Gates**: Control migration flow at critical checkpoints
✅ **Parallel Migrations**: Migrate up to 5 repositories concurrently
✅ **Comprehensive Validation**: Pre-migration readiness checks and post-migration verification
✅ **Pipeline Rewiring**: Automatically update ADO pipelines to use GitHub repos
✅ **Azure Boards Integration**: Enable work item linking with GitHub commits/PRs
✅ **Security Isolation**: Separate PAT tokens with minimal required scopes
✅ **Detailed Logging**: Individual log files for each stage and repository
✅ **Status Tracking**: CSV output with migration results
✅ **Error Handling**: Continues even if some migrations fail
✅ **Artifact Publishing**: All logs preserved as build artifacts

## Support and Troubleshooting

### Common Issues

**Issue: Pipeline fails at Stage 1 (Prerequisite Validation)**
- **Solution**: Verify `bash/repos.csv` exists and contains all required columns: `org`, `teamproject`, `repo`, `github_org`, `github_repo`, `gh_repo_visibility`

**Issue: "Variable group 'core-entauto-github-migration-secrets' could not be found"**
- **Solution**: Create the migration variable group with `GH_TOKEN` and `ADO_PAT`. See Prerequisites section above.

**Issue: "Variable group 'azure-boards-integration-secrets' could not be found" (Stage 6)**
- **Solution**: Create the Boards integration variable group with `GH_PAT` and `ADO_PAT` (Boards-only scopes). See [PAT_TOKEN_CONFIGURATION.md](PAT_TOKEN_CONFIGURATION.md)

**Issue: "ADO_PAT environment variable is not set"**
- **Solution**: Ensure the appropriate variable group contains `ADO_PAT` as a secret variable. Remember: different ADO_PAT tokens are used in different stages.

**Issue: "Repository already exists in GitHub"**
- **Solution**: Delete the existing repository in GitHub or use a different name in `repos.csv`

**Issue: "Authentication failed" or "Permission denied"**
- **Solution**: Verify PAT tokens have correct scopes and haven't expired. See [PAT_TOKEN_CONFIGURATION.md](PAT_TOKEN_CONFIGURATION.md) for required scopes.

**Issue: Migration timeout**
- **Solution**: Reduce `maxConcurrent` value (line 8 in YAML) or increase `timeoutInMinutes` for the migration task

**Issue: "Work item access denied" (Stage 6)**
- **Solution**: Verify the `ADO_PAT` in `azure-boards-integration-secrets` has Work Items (Read, Write) scope

**Issue: Pipeline rewiring fails (Stage 5)**
- **Solution**: Ensure `bash/pipelines.csv` exists with correct service connection IDs and all required columns

### Pipeline Monitoring

Monitor pipeline execution:
1. **Real-time**: Watch logs in Azure DevOps UI during execution
2. **Post-run**: Review artifacts and summary logs
3. **Status Bar**: Check migration progress in Stage 3 logs

### Getting Help

For issues or questions:
1. Review the individual log files in artifacts
2. Check the pipeline run summary for error messages
3. Verify all prerequisites are met
4. Review the `gh-ado2gh` documentation: https://github.com/github/gh-ado2gh

## 📄 License

This pipeline configuration is provided as-is for Azure DevOps to GitHub migration purposes.
