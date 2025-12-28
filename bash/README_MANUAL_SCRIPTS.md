# Manual Use Scripts

This directory contains a script that is **NOT** part of the automated pipeline but can be used manually if needed.

## 6_disable_ado_repo.sh.MANUAL_USE_ONLY

**Purpose**: Disables Azure DevOps repositories after migration to GitHub.

**Why not in pipeline?**  
This stage was removed from the pipeline to preserve rerun capability. If downstream stages show partial success (SucceededWithIssues), users need to review logs, fix issues, and re-run the pipeline. Automatically disabling ADO repos would prevent reruns.

**When to use manually:**
- After confirming migration is 100% stable
- When you're certain no pipeline reruns are needed
- When you want to prevent further commits to ADO repos

**Usage:**
```bash
cd bash
# Make executable
chmod +x 6_disable_ado_repo.sh.MANUAL_USE_ONLY

# Ensure repos_with_status.csv is in current directory
# (Download from pipeline artifacts if needed)

# Set required environment variables
export ADO_PAT="your-ado-pat-token"
export GH_PAT="your-github-pat-token"

# Run the script
./6_disable_ado_repo.sh.MANUAL_USE_ONLY
```

**Prerequisites:**
- `repos_with_status.csv` file (from Migration stage artifacts)
- ADO_PAT environment variable
- GH_PAT environment variable
- gh CLI with ado2gh extension installed

**Output:**
- Creates log file: `disable-ado-repos-YYYYMMDD-HHMMSS.log`
- Disables repositories marked as "Success" in repos_with_status.csv
