# ADO to GitHub Migration Pipeline

This repository contains an automated Azure DevOps pipeline for migrating repositories from Azure DevOps to GitHub using the `gh-ado2gh` extension.

## What This Pipeline Does

The **ADO to GitHub Migration Pipeline** automates the complete migration process from Azure DevOps repositories to GitHub in four sequential stages:

### Stage 1: Prerequisite Validation
- Verifies that `bash/repos.csv` file exists
- Validates that the CSV contains all required columns:
  - `github_org`
  - `github_repo`
  - `gh_repo_visibility`
- Displays the number of repositories to be migrated

### Stage 2: Migration Readiness Check
- Scans source repositories for active pull requests
- Checks for running builds and releases
- Identifies potential blockers before migration begins
- Generates a readiness report

### Stage 3: Migration
- Installs GitHub CLI and `gh-ado2gh` extension
- Executes parallel migrations (configurable: 1-5 concurrent migrations)
- Migrates repository content, branches, and commit history
- Generates migration status logs for each repository
- Creates a summary CSV with migration results

### Stage 4: Post-Migration Validation
- Validates each migrated repository in GitHub
- Compares branches between source (ADO) and target (GitHub)
- Verifies repository accessibility and structure
- Generates validation logs with detailed results

## Prerequisites

Before running this pipeline, ensure the following requirements are met:

### 1. Variable Group Configuration ⚠️ MANDATORY
Create a variable group named `core-entauto-github-migration-secrets` in Azure DevOps with the following variables:

| Variable Name | Description | Required |
|--------------|-------------|----------|
| `GH_TOKEN` | GitHub Personal Access Token with `repo` and `admin:org` scopes | ✅ Yes |
| `ADO_PAT` | Azure DevOps Personal Access Token with full access | ✅ Yes |

> **⚠️ IMPORTANT**: This variable group is **mandatory**. The pipeline will fail immediately if it doesn't exist. You must create it before running the pipeline for the first time.

**Step-by-step instructions to create the variable group:**

1. **Navigate to Library in Azure DevOps:**
   - Open your browser and go to: https://dev.azure.com/contosodevopstest/ado2gh-ado-pipelines/_library
   - Or navigate manually: Click **Pipelines** in the left menu → Click **Library**

2. **Create a new Variable Group:**
   - Click the **+ Variable group** button at the top
   
3. **Configure the variable group:**
   - **Variable group name**: Enter `core-entauto-github-migration-secrets` (must match exactly)
   - **Description** (optional): "GitHub and Azure DevOps PAT tokens for repository migration"
   
4. **Add the GH_TOKEN variable:**
   - Click **+ Add** under Variables section
   - **Name**: `GH_TOKEN`
   - **Value**: Paste your GitHub Personal Access Token (you'll create this in step 2 below)
   - Click the **lock icon** 🔒 to mark it as **secret**
   
5. **Add the ADO_PAT variable:**
   - Click **+ Add** again
   - **Name**: `ADO_PAT`
   - **Value**: Paste your Azure DevOps Personal Access Token (you'll create this in step 3 below)
   - Click the **lock icon** 🔒 to mark it as **secret**

6. **Set permissions (if needed):**
   - Click **Pipeline permissions** tab
   - If the pipeline isn't automatically authorized, click **+** and add "ADO to GitHub Migration Pipeline"
   - This allows the pipeline to access the variable group

7. **Save the variable group:**
   - Click **Save** at the top

**Verification:**
After creating the variable group, you should see:
- Variable group name: `core-entauto-github-migration-secrets`
- 2 variables: `GH_TOKEN` (**secret**), `ADO_PAT` (**secret**)
- Both variables should show 🔒 (locked) indicating they are secret

### 2. GitHub Personal Access Token (PAT)
Create a GitHub PAT with the following scopes:
- `repo` (Full control of private repositories)
- `admin:org` (Full control of orgs and teams, read and write org projects)
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

## How to Update repos.csv and Run the Pipeline

### Updating repos.csv

1. **Edit the CSV file:**
   ```bash
   # Navigate to the repository
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

### Running the Pipeline

#### Option 1: Via Azure DevOps Web UI
1. Navigate to: https://dev.azure.com/contosodevopstest/ado2gh-ado-pipelines/_build
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
  --organization https://dev.azure.com/contosodevopstest
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

**Recommendations:**
- **1-2 concurrent**: For large repositories or slow network
- **3 concurrent**: Default, balanced approach
- **4-5 concurrent**: For small repositories and fast network

## Pipeline Run Logs

### Accessing Pipeline Logs

#### 1. View Logs in Azure DevOps UI
1. Navigate to the pipeline run: https://dev.azure.com/contosodevopstest/ado2gh-ado-pipelines/_build
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

#### 3. Log Files Location in Artifacts

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

### Troubleshooting Failed Migrations

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

## Pipeline Structure

```
ado2gh-ado-pipelines/
├── ado2gh-migration.yml                          # Main pipeline definition
├── bash/
│   ├── 1_migration_readiness_check.sh           # Readiness validation script
│   ├── 2_migration.sh                           # Migration execution script
│   ├── 3_post_migration_validation.sh           # Post-migration validation script
│   └── repos.csv                                # Repository list
├── .gitattributes                                # Git line ending configuration
└── README.md                                     # This file
```

## Key Features

✅ **Parallel Migrations**: Migrate up to 5 repositories concurrently
✅ **Comprehensive Validation**: Pre-migration readiness checks and post-migration verification
✅ **Detailed Logging**: Individual log files for each repository migration
✅ **Status Tracking**: CSV output with migration results
✅ **Error Handling**: Continues even if some migrations fail
✅ **Artifact Publishing**: All logs preserved as build artifacts

## Support and Troubleshooting

### Common Issues

**Issue: Pipeline fails at Stage 1 (Prerequisite Validation)**
- **Solution**: Verify `bash/repos.csv` exists and contains required columns

**Issue: "GH_PAT environment variable is not set"**
- **Solution**: Ensure `GH_TOKEN` variable is set in the variable group

**Issue: "Repository already exists in GitHub"**
- **Solution**: Delete the existing repository in GitHub or use a different name

**Issue: "Authentication failed"**
- **Solution**: Verify PAT tokens have correct permissions and haven't expired

**Issue: Migration timeout**
- **Solution**: Reduce `maxConcurrent` value or increase `timeoutInMinutes` in YAML

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

## License

This pipeline configuration is provided as-is for Azure DevOps to GitHub migration purposes.
