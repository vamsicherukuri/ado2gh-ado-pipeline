\# 🚀 ADO to GitHub Migration Pipeline



Migrating repositories from Azure DevOps (ADO) to GitHub Enterprise (GHE) using a hybrid approach is inherently challenging due to the multiple stages involved in the end-to-end process. 

Even with automation scripts, this process can be cumbersome and difficult to scale, especially for organizations managing tens of thousands of repositories. I encountered a scenario where an organization needed to migrate nearly 20,000 repositories, making it impractical to rely solely on scripts to execute both migration and post-migration steps in a centralized manner.



To address this scalability challenge, I designed a stage-based Azure DevOps YAML pipeline that encapsulates the entire migration lifecycle from prerequisite validation through successful migration, post-migration rewiring, Azure Boards integration, and safe decommissioning of the ADO repository. This pipeline enables a decentralized, self-service migration model, where individual teams can independently migrate only the repositories they own.



By distributing ownership to teams and allowing migrations to run in parallel, this approach scales effectively for large enterprises, avoids centralized bottlenecks and big-bang migrations, and makes the overall ADO-to-GHE migration process more manageable, controlled, and resilient.



---



\## 📋 Table of Contents



\- \[Quick Start](#-quick-start-your-first-migration)

\- \[Problem Statement \& Solution](#-problem-statement--solution)

\- \[Pipeline Architecture](#-pipeline-stages-overview)

\- \[Prerequisites](#%EF%B8%8F-prerequisites)

\- \[Migration at Scale](#-migration-at-scale)

\- \[Manual Approval Gates](#%EF%B8%8F-manual-approval-gate-guidelines)

\- \[How to Run](#-how-to-update-reposcsv-and-run-the-pipeline)

\- \[Understanding Logs](#-understanding-pipeline-logs)

\- \[Troubleshooting](#-troubleshooting)

\- \[FAQ](#-frequently-asked-questions)

\- \[Operational Runbook](#-migration-runbook)

\- \[Scope \& Limitations](#%EF%B8%8F-scope--limitations)



---



\## 🚀 Quick Start: Your First Migration



\### Prerequisites Checklist



Before running your first migration, ensure you have completed the following:



\- \[ ] Variable groups created and populated (`core-entauto-github-migration-secrets` and `azure-boards-integration-secrets`)

\- \[ ] GitHub organizations exist and you have \*\*Owner\*\* or \*\*Admin\*\* access

\- \[ ] GitHub service connection configured in Azure DevOps (required for Stage 5)

\- \[ ] `bash/repos.csv` prepared with 1-3 test repositories

\- \[ ] `bash/pipelines.csv` prepared (if pipeline rewiring is needed)

\- \[ ] ADO PAT token has required permissions (Code: Read/Write, Build, Service Connections)

\- \[ ] GitHub PAT token has required scopes (see \[Prerequisites](#%EF%B8%8F-prerequisites))



\### Step-by-Step First Run



1\. \*\*Prepare your repos.csv\*\*

&nbsp;  ```bash

&nbsp;  # Navigate to the repository directory

&nbsp;  cd c:\\Users\\<username>\\factory\\ado2gh-ado-pipelines

&nbsp;  

&nbsp;  # Edit repos.csv with your test repositories

&nbsp;  code bash/repos.csv

&nbsp;  ```



2\. \*\*Add test repository entries\*\* (start with 1-3 repos):

&nbsp;  ```csv

&nbsp;  org,teamproject,repo,github\_org,github\_repo,gh\_repo\_visibility

&nbsp;  mycompany,Platform,api-service,mycompany-gh,platform-api,private

&nbsp;  mycompany,Platform,web-frontend,mycompany-gh,platform-web,private

&nbsp;  ```



3\. \*\*Commit and push your changes\*\*:

&nbsp;  ```bash

&nbsp;  git add bash/repos.csv

&nbsp;  git commit -m "Add test repositories for first migration"

&nbsp;  git push

&nbsp;  ```



4\. \*\*Run the pipeline\*\*:

&nbsp;  - Navigate to: `https://dev.azure.com/<org>/<project>/\_build`

&nbsp;  - Click \*\*ADO to GitHub Migration Pipeline\*\*

&nbsp;  - Click \*\*Run pipeline\*\*

&nbsp;  - Select branch: `main`

&nbsp;  - Click \*\*Run\*\*



5\. \*\*Monitor Stage 1\*\* (Prerequisite Validation):

&nbsp;  - Should complete in < 1 minute

&nbsp;  - Validates CSV format and displays repository count

&nbsp;  - Check for any errors



6\. \*\*Monitor Stage 2\*\* (Pre-migration Check):

&nbsp;  - Reviews readiness report for active PRs and pipelines

&nbsp;  - Download `readiness-logs` artifact to review findings

&nbsp;  - ⏸️ \*\*APPROVAL REQUIRED\*\*: Review and approve/reject based on findings



7\. \*\*Monitor Stage 3\*\* (Repository Migration):

&nbsp;  - Actual migration happens here

&nbsp;  - Monitor logs for progress (can take 2-30 minutes depending on repo size)

&nbsp;  - Download `migration-logs` artifact when complete



8\. \*\*Monitor Stage 4\*\* (Migration Validation):

&nbsp;  - Compares branches and commits between ADO and GitHub

&nbsp;  - Download `validation-logs` artifact

&nbsp;  - ⏸️ \*\*APPROVAL REQUIRED\*\*: Review validation results



9\. \*\*Monitor Stage 5\*\* (Pipeline Rewiring):

&nbsp;  - Rewires ADO pipelines to use GitHub repos

&nbsp;  - Download `rewiring-logs` artifact

&nbsp;  - ⏸️ \*\*APPROVAL REQUIRED\*\*: Confirm pipelines rewired successfully



10\. \*\*Monitor Stage 6\*\* (Boards Integration):

&nbsp;   - Integrates Azure Boards with GitHub repos

&nbsp;   - Download `boards-integration-logs` artifact

&nbsp;   - ✅ \*\*Migration Complete!\*\*



\### Example repos.csv Entry



```csv

org,teamproject,repo,github\_org,github\_repo,gh\_repo\_visibility

mycompany,Platform,api-service,mycompany-gh,platform-api,private

mycompany,DataServices,analytics-engine,mycompany-gh,data-analytics,internal

mycompany,Mobile,ios-app,mycompany-gh,mobile-ios,private

```



\*\*Column Definitions:\*\*

\- `org`: Azure DevOps organization name (e.g., `mycompany`)

\- `teamproject`: Azure DevOps project name (e.g., `Platform`)

\- `repo`: Azure DevOps repository name (e.g., `api-service`)

\- `github\_org`: Target GitHub organization (e.g., `mycompany-gh`)

\- `github\_repo`: Target GitHub repository name (e.g., `platform-api`)

\- `gh\_repo\_visibility`: Repository visibility (`private`, `public`, or `internal`)



---



\## 🎯 Problem Statement \& Solution



\### The Challenge



Migrating thousands of repositories from Azure DevOps to GitHub at enterprise scale presents several challenges:



\- \*\*Script-only approaches don't scale\*\*: Running migration scripts serially from a single machine is too slow for 1,000+ repositories

\- \*\*Centralized bottleneck\*\*: One team managing all migrations creates dependency and delays

\- \*\*Big-bang risk\*\*: Migrating everything at once increases failure risk and rollback complexity

\- \*\*Lack of validation\*\*: Manual post-migration checks are error-prone and time-consuming

\- \*\*State management\*\*: Tracking which repos have been migrated, validated, and rewired is complex



\### The Solution



This pipeline-based approach solves these challenges by:



✅ \*\*Decentralized self-service\*\*: Teams migrate their own repositories on their own schedule  

✅ \*\*Parallel execution\*\*: Multiple migration batches can run concurrently (within rate limits)  

✅ \*\*Automated validation\*\*: Built-in checks ensure migration completeness (branches, commits, SHAs)  

✅ \*\*Staged approvals\*\*: Manual gates enforce review before proceeding to next stage  

✅ \*\*Comprehensive logging\*\*: Detailed artifacts enable troubleshooting and audit trails  

✅ \*\*Repeatable process\*\*: YAML pipeline ensures consistency across all migrations



\### Who Should Use This Pipeline



\*\*Target Users:\*\*

\- DevOps engineers managing repository migrations

\- Development teams migrating their own repositories (self-service)

\- Platform teams coordinating large-scale migrations



\*\*Required Skills:\*\*

\- Basic understanding of Git and version control

\- Familiarity with Azure DevOps and Azure Pipelines

\- Ability to edit CSV files and commit changes

\- Understanding of GitHub organizations and repositories



\*\*When to Use This Pipeline:\*\*

\- ✅ Migrating 10+ repositories (batch migration)

\- ✅ Need for automated validation and approval gates

\- ✅ Require pipeline rewiring and boards integration

\- ✅ Want comprehensive logging and audit trails



\*\*When NOT to Use This Pipeline:\*\*

\- ❌ Single repository migration (use `gh ado2gh migrate-repo` CLI command directly)

\- ❌ Repositories with complex monorepo dependencies requiring custom transformations

\- ❌ Migrations requiring commit history rewriting or filtering



---



\## 🏗️ Pipeline Stages Overview



This pipeline is designed to run on Ubuntu Linux using Microsoft-hosted Azure Pipelines agents with the `ubuntu-latest` VM image. The pipeline executes 6 stages sequentially, where each stage runs on a completely fresh Ubuntu runner with no state carried over from previous stages.



The three manual approval gates use `pool: server` (no agent required) with a 24-hour timeout, and each regular stage runs with the `condition: succeeded()` to ensure it only executes if the previous stage completed successfully. Since each stage gets a fresh runner, tools like GitHub CLI and the gh-ado2gh extension are reinstalled in every stage that needs them.



```mermaid

---

config:

&nbsp; theme: neo

&nbsp; layout: dagre

&nbsp; look: handDrawn

---

flowchart TB

&nbsp;   Start\["<b>Start YAML Pipeline</b>"] --> Stage1\["<b>Stage 1: Prereq validation</b><br>Verify repos.csv<br>Validate CSV columns<br>Display repository count"]

&nbsp;   Stage1 --> Stage2\["<b>Stage 2: Pre-migration check</b><br>Check for active PR<br>Check for active pipelines<br>Generate readiness logs"]

&nbsp;   Stage2 --> Gate1\["<b>User approval</b><br>Approval checkpoint to trigger the next stage"]

&nbsp;   Gate1 -- Approved --> Stage3\["<b>Stage 3: Repository Migration</b><br>Install GH CLI \&amp; ado2gh<br>Migrate repos<br>Generate migration logs"]

&nbsp;   Gate1 -- Rejected --> End1\["<b>Pipeline Cancelled</b>"]

&nbsp;   Stage3 --> Stage4\["<b>Stage 4: Migration Validation</b><br>Compare ADO and GH repos<br>branch count<br>commit counts per branch<br>SHAs match, proving commit history is intact"]

&nbsp;   Stage4 --> Gate2\["<b>User Approval</b><br>Review validation results \&amp; trigger next stage"]

&nbsp;   Gate2 -- Approved --> Stage5\["<b>Stage 5: Pipeline Rewiring</b><br>Validate GH \&amp; ADO PAT tokens<br>Validate pipelines.csv<br>rewire pipeline to GH repo<br>Use GH service connection<br>Generate rewiring logs"]

&nbsp;   Gate2 -- Rejected --> End2(\["<b>Pipeline Cancelled</b>"])

&nbsp;   Stage5 --> Gate3\["<b>User Approval</b><br>Review Rewiring status \&amp; trigger next stage"]

&nbsp;   Gate3 -- Approved --> Stage6\["<b>Stage 6: Boards Integration</b><br>Integrate boards<br>Enable <b>AB#</b> linking<br>Generate Logs"]

&nbsp;   Gate3 -- Rejected --> End3(\["<b>Pipeline Cancelled</b>"])

&nbsp;   Stage6 --> Success(\["<b>Migration Complete ✓</b>"])



&nbsp;   Start@{ shape: tag-proc}

&nbsp;   Stage1@{ shape: procs}

&nbsp;   Stage2@{ shape: procs}

&nbsp;   Gate1@{ shape: doc}

&nbsp;   Stage3@{ shape: procs}

&nbsp;   End1@{ shape: terminal}

&nbsp;   Stage4@{ shape: procs}

&nbsp;   Gate2@{ shape: doc}

&nbsp;   Stage5@{ shape: procs}

&nbsp;   Gate3@{ shape: doc}

&nbsp;   Stage6@{ shape: procs}

&nbsp;   style Stage1 fill:#e1f5ff,stroke-width:1px,stroke-dasharray: 0

&nbsp;   style Stage2 fill:#e1f5ff

&nbsp;   style Gate1 fill:#FFF9C4

&nbsp;   style Stage3 fill:#e1f5ff

&nbsp;   style End1 fill:#ffcccc

&nbsp;   style Stage4 fill:#e1f5ff

&nbsp;   style Gate2 fill:#FFF9C4

&nbsp;   style Stage5 fill:#e1f5ff

&nbsp;   style End2 fill:#ffcccc

&nbsp;   style Gate3 fill:#FFF9C4

&nbsp;   style Stage6 fill:#e1f5ff

&nbsp;   style End3 fill:#ffcccc

&nbsp;   style Success fill:#e1ffe1

```

> \*\*⚠️ IMPORTANT\*\*: Manual approval gates are enforced after Stage 2, Stage 4, and Stage 5. The pipeline remains paused at the preceding stage until approval is provided. Each of these stages must be manually validated before proceeding to the next stage.



\### Stage 1: Prerequisite Validation

\- Verifies that `bash/repos.csv` file exists and is not empty

\- Validates that the CSV contains all required columns:

&nbsp; - `org`, `teamproject`, `repo`

&nbsp; - `github\_org`, `github\_repo`, `gh\_repo\_visibility`

\- Displays the number of repositories to be migrated



\### Stage 2: Pre-migration check

Executes `1\_pr\_pipeline\_check.sh` to:



\- Scans source repositories for active pull requests

\- Detectes active builds, releases pipelines, and pull requests

\- Identifies potential blockers before migration begins

\- Generates a readiness report

\- \*\*⏸️ User approval:\*\* Review readiness before proceeding to next stage 3: Repository Migration



\### Stage 3: Repository Migration

Executes `2\_migration.sh` to perform the actual migration:



\- Installs GitHub CLI and `gh-ado2gh` extension

\- Executes parallel migrations (configurable: 1-5 concurrent migrations in the script)

\- Migrates repository content, branches, and commit history

\- Generates migration status logs for each repository

\- Creates a summary CSV with migration results



\### Stage 4: Repository Migration Validation

Executes `3\_post\_migration\_validation.sh` to:



-Branch Comparison - Compares branch counts between ADO and GitHub, identifies any missing branches on either side.

-Commit Validation - For each branch, verifies the latest commit SHA matches between ADO and GitHub to ensure complete migration.

-Commit Count Verification - Compares total commit counts per branch between source (ADO) and target (GitHub) to detect any missing commits.

\- Generates validation logs with detailed results

\- \*\*⏸️ User approval:\*\* Review validation before proceeding to next stage 5: Pipeline Rewiring



\### Stage 5: Pipeline Rewiring

Executes `4\_rewire\_pipeline.sh` to:



\- Validate github and ADO tokens.

\- Reads pipeline configurations from `bash/pipelines.csv`

\- Rewires Azure DevOps pipelines to use GitHub repositories

\- Updates service connections and repository sources

\- Validates pipeline configurations

\- Generates rewiring logs

\- \*\*⏸️ User approval:\*\* Review validation before proceeding to next stage 6: boards Integration



\### Stage 6: Azure Boards Integration

Executes `5\_boards\_integration.sh` to:



\- Validates github and ADO PAT tokens (for this stage github PAT tokens should created with the follwing scope: repo; admin:repo\_hook; read:user; user:email).

\- Integrates Azure Boards with migrated GitHub repositories.

\- Enables AB# work item linking in GitHub commits/PRs.



---



\## ⚙️ Prerequisites



Before running this pipeline, ensure the following requirements are met:



\### 1. Operating System

\*\*Required\*\*: Ubuntu Linux (latest) - `vmImage: 'ubuntu-latest'`



The pipeline is designed to run on Microsoft-hosted Azure Pipelines Ubuntu agents. Do not change the VM image unless you have tested compatibility.



\### 2. GitHub Organization Preparation



\*\*Before running the pipeline, ensure:\*\*



1\. Navigate to `https://github.com/enterprises/<YOUR\_ENTERPRISE>/organizations`

2\. Verify target GitHub organizations exist (e.g., `mycompany-gh`)

3\. Confirm you have \*\*Owner\*\* or \*\*Admin\*\* role in the target organizations

4\. If creating new organizations:

&nbsp;  - Follow your organization's GitHub Enterprise org creation process

&nbsp;  - Ensure proper naming conventions are followed

&nbsp;  - Configure organization settings (member privileges, repository defaults, etc.)



\*\*Required GitHub Organization Settings:\*\*

\- Member repository creation: Enabled (or admin creates repos beforehand)

\- Repository visibility options: Match your `gh\_repo\_visibility` settings in CSV

\- Base permissions: Read (migration will create repos with appropriate teams/permissions)



\### 3. GitHub Service Connection Setup (Required for Stage 5)



\*\*Creating the GitHub Service Connection:\*\*



1\. Navigate to Azure DevOps: `https://dev.azure.com/<org>/<project>/\_settings/adminservices`

2\. Click \*\*New service connection\*\* → Select \*\*GitHub\*\*

3\. Choose authentication method: \*\*Personal Access Token\*\*

4\. Fill in connection details:

&nbsp;  - \*\*Connection name\*\*: `GitHub-<OrgName>-Connection` (e.g., `GitHub-MyCompanyGH-Connection`)

&nbsp;  - \*\*Server URL\*\*: `https://github.com` (or your GitHub Enterprise URL)

&nbsp;  - \*\*Personal Access Token\*\*: Use the same token from `core-entauto-github-migration-secrets` variable group

5\. Click \*\*Verify and save\*\*



\*\*Getting the Service Connection ID:\*\*



After creating the connection:

\- Open the service connection from the list

\- The ID is in the URL: `https://dev.azure.com/<org>/<project>/\_settings/adminservices?resourceId=<SERVICE\_CONNECTION\_ID>`

\- Or click on the connection and copy the ID from the details page



\*\*Add the ID to pipelines.csv:\*\*

```csv

org,teamproject,pipeline,github\_org,github\_repo,serviceConnection

mycompany,Platform,api-ci-pipeline,mycompany-gh,platform-api,12345678-1234-1234-1234-123456789abc

```



> \*\*⚠️ IMPORTANT\*\*: The service connection must have \*\*Contributor\*\* access to the GitHub organization and repositories.



\### 4. Personal Access Token (PAT) Setup



\*\*GitHub PAT Creation (Stages 1-5 - Migration):\*\*



1\. Navigate to GitHub: `https://github.com/settings/tokens`

2\. Click \*\*Generate new token\*\* → \*\*Generate new token (classic)\*\*

3\. \*\*Token name\*\*: `ADO-to-GitHub-Migration-Token`

4\. \*\*Expiration\*\*: 90 days (recommended) or custom

5\. \*\*Select scopes\*\*:

&nbsp;  - ✅ `repo` (Full control of private repositories)

&nbsp;  - ✅ `workflow` (Update GitHub Action workflows)

&nbsp;  - ✅ `admin:org` (Full control of orgs and teams)

&nbsp;  - ✅ `read:user` (Read user profile data)

6\. Click \*\*Generate token\*\*

7\. \*\*Copy and save the token immediately\*\* (you won't see it again)



\*\*GitHub PAT Creation (Stage 6 - Boards Integration):\*\*



1\. Create a \*\*separate\*\* GitHub PAT with limited scopes for security:

&nbsp;  - ✅ `repo` (Full control of private repositories)

&nbsp;  - ✅ `admin:repo\_hook` (Full control of repository hooks)

&nbsp;  - ✅ `read:user` (Read user profile data)

&nbsp;  - ✅ `user:email` (Access user email addresses)

2\. Name it: `ADO-Boards-Integration-Token`



\*\*Azure DevOps PAT Creation (Stages 1-5 - Migration):\*\*



1\. Navigate to: `https://dev.azure.com/<org>/\_usersSettings/tokens`

2\. Click \*\*New Token\*\*

3\. \*\*Name\*\*: `GitHub-Migration-Token`

4\. \*\*Organization\*\*: Select your ADO organization

5\. \*\*Expiration\*\*: 90 days (custom)

6\. \*\*Scopes\*\* (Custom defined):

&nbsp;  - ✅ \*\*Code\*\*: Read \& Write

&nbsp;  - ✅ \*\*Build\*\*: Read \& Execute

&nbsp;  - ✅ \*\*Service Connections\*\*: Read, Query \& Manage

7\. Click \*\*Create\*\*

8\. \*\*Copy and save the token immediately\*\*



\*\*Azure DevOps PAT Creation (Stage 6 - Boards Integration):\*\*



1\. Create a \*\*separate\*\* ADO PAT with limited scopes:

&nbsp;  - ✅ \*\*Code\*\*: Read only

&nbsp;  - ✅ \*\*Work Items\*\*: Read \& Write

&nbsp;  - ✅ \*\*Project and Team\*\*: Read

2\. Name it: `Boards-Integration-Token`



> \*\*🔒 Security Best Practice\*\*: Use separate PATs for migration vs. boards integration to follow principle of least privilege.



\### 5. Variable Group Configuration ⚠️ MANDATORY



This pipeline requires \*\*TWO separate variable groups\*\* for security isolation:



\#### A. Migration Variable Group: `core-entauto-github-migration-secrets`



Stages 1–5 (Prerequisites, Pre-Migration Checks, Migration, Validation, and Rewiring) use one set of GitHub PATs, while Stage 6 (Boards Integration) requires separate GitHub PATs with different scopes.



| Variable Name | Description | Required |

|--------------|-------------|----------|

| `GH\_PAT` | GitHub Personal Access Token with `admin:org`, `read:user`, `repo`, `workflow` scopes | ✅ Yes |  

| `ADO\_PAT` | Azure DevOps PAT with Code (Read, Write), Build, Service Connections scopes | ✅ Yes |



\#### B. Boards Integration Variable Group: `azure-boards-integration-secrets`



Used in Stage 6 (Azure Boards Integration) - \*\*SEPARATE token with limited scopes\*\*



| Variable Name | Description | Required |

|--------------|-------------|----------|

| `GH\_PAT` | GitHub Personal Access Token with `repo`, `admin:org` scopes | ✅ Yes |  

| `ADO\_PAT` | Azure DevOps PAT with Code (Read only), Work Items (Read, Write), Project/Team (Read) - \*\*DIFFERENT from migration ADO\_PAT\*\* | ✅ Yes |



> \*\*⚠️ IMPORTANT\*\*: Both variable groups are required for the pipeline to run successfully. If either variable group does not exist, the pipeline will fail. Create them prior to the initial pipeline run. If variable groups are created with different names than those referenced above, the YAML must be updated accordingly.



\*\*Step-by-step instructions to create variable groups:\*\*



1\. \*\*Navigate to Library in Azure DevOps:\*\*

&nbsp;  - Open your browser and go to: `https://dev.azure.com/<org>/<project>/\_library`

&nbsp;  - Or navigate manually: Click \*\*Pipelines\*\* in the left menu → Click \*\*Library\*\*



2\. \*\*Create the first variable group (Migration):\*\*

&nbsp;  - Click the \*\*+ Variable group\*\* button at the top

&nbsp;  - \*\*Variable group name\*\*: Enter `core-entauto-github-migration-secrets` (must match exactly)

&nbsp;  - \*\*Description\*\*: "Migration PAT tokens for ADO to GitHub migration (Stages 1-5)"

&nbsp;  - Click \*\*+ Add\*\* to add `GH\_PAT` → paste token → click 🔒 to mark as secret

&nbsp;  - Click \*\*+ Add\*\* to add `ADO\_PAT` → paste migration token → click 🔒 to mark as secret

&nbsp;  - Click \*\*Save\*\*



3\. \*\*Create the second variable group (Boards Integration):\*\*



4\. \*\*Set permissions (if needed):\*\*

&nbsp;  - Click \*\*Pipeline permissions\*\* tab

&nbsp;  - If the pipeline isn't automatically authorized, click \*\*+\*\* and add "ADO to GitHub Migration Pipeline"

&nbsp;  - This allows the pipeline to access the variable group



5\. \*\*Save the variable group:\*\*

&nbsp;  - Click \*\*Save\*\* at the top

&nbsp; 

After creating the variable group, you should see:

\- Variable group name: `core-entauto-github-migration-secrets`

\- 2 variables: `GH\_TOKEN` (\*\*secret\*\*), `ADO\_PAT` (\*\*secret\*\*)

\- Both variables should show 🔒 (locked) indicating they are secret



\### 6. Repository CSV File Preparation



The `bash/repos.csv` file must exist with the following structure:



\*\*Required columns:\*\*

\- `org` - Azure DevOps organization name

\- `teamproject` - Azure DevOps project name

\- `repo` - Azure DevOps repository name

\- `github\_org` - Target GitHub organization

\- `github\_repo` - Target GitHub repository name

\- `gh\_repo\_visibility` - Repository visibility: `private`, `public`, or `internal`



\*\*Creating repos.csv:\*\*



\*\*Option A: Manual Creation (for < 10 repos)\*\*



```bash

\# Create the file

touch bash/repos.csv



\# Add header row

echo "org,teamproject,repo,github\_org,github\_repo,gh\_repo\_visibility" > bash/repos.csv



\# Add repository entries (one per line)

echo "mycompany,Platform,api-service,mycompany-gh,platform-api,private" >> bash/repos.csv

echo "mycompany,Platform,web-frontend,mycompany-gh,platform-web,private" >> bash/repos.csv

```



\*\*Option B: Export from Azure DevOps (recommended for 10+ repos)\*\*



```bash

\# Install Azure DevOps CLI extension

az extension add --name azure-devops



\# Set default organization

az devops configure --defaults organization=https://dev.azure.com/mycompany



\# List all repositories in a project

az repos list --project Platform --output table



\# Export to CSV (requires custom script or manual export)

\# You can use the Azure DevOps REST API to automate this:

\# https://dev.azure.com/mycompany/Platform/\_apis/git/repositories

```



\*\*CSV Formatting Best Practices:\*\*

\- No spaces after commas unless part of the value

\- Quote values containing commas: `"Team Project, Legacy"`

\- One repository per line

\- No empty lines between entries

\- UTF-8 encoding (without BOM)



\*\*Example repos.csv:\*\*



```csv

org,teamproject,repo,github\_org,github\_repo,gh\_repo\_visibility

mycompany,Platform,api-service,mycompany-gh,platform-api,private

mycompany,Platform,web-frontend,mycompany-gh,platform-web,internal

mycompany,DataServices,analytics-engine,mycompany-gh,data-analytics,private

mycompany,Mobile,ios-app,mycompany-gh,mobile-ios,private

mycompany,Mobile,android-app,mycompany-gh,mobile-android,private

```



\### 7. Pipeline CSV File (Required for Stage 5)

The `bash/pipelines.csv` file must exist with the following structure for pipeline rewiring:



\*\*Required columns:\*\*

\- `org` - Azure DevOps organization name

\- `teamproject` - Azure DevOps project name

\- `pipeline` - Pipeline name/path to rewire

\- `github\_org` - Target GitHub organization

\- `github\_repo` - Target GitHub repository name

\- `serviceConnection` - Azure DevOps GitHub service connection ID



\*\*Example pipelines.csv:\*\*



```csv

org,teamproject,pipeline,github\_org,github\_repo,serviceConnection

mycompany,Platform,api-ci-pipeline,mycompany-gh,platform-api,12345678-1234-1234-1234-123456789abc

mycompany,Platform,web-cd-pipeline,mycompany-gh,platform-web,12345678-1234-1234-1234-123456789abc

```



---



\## 📊 Migration at Scale



\### Recommended Batch Sizes



The following batch sizes are based on experience migrating thousands of repositories:



| Team Size | Repository Count | Recommended Batch Size | Estimated Duration |

|-----------|-----------------|------------------------|-------------------|

| \*\*Small\*\* | 1-10 repos | Migrate all at once | 30 minutes - 1 hour |

| \*\*Medium\*\* | 10-100 repos | Batch in groups of 10-20 | 1-2 hours per batch |

| \*\*Large\*\* | 100-500 repos | Batch in groups of 50 | 3-4 hours per batch |

| \*\*Enterprise\*\* | 1000+ repos | Batch in groups of 50-100 | Coordinate with platform team |



\### Concurrency Settings



Configure the `maxConcurrent` variable in `ado2gh-migration.yml` based on your requirements:



```yaml

variables:

&nbsp; - group: core-entauto-github-migration-secrets

&nbsp; - name: maxConcurrent

&nbsp;   value: 3  # Change this value (1-5)

```



\*\*Concurrency Guidelines:\*\*



| Setting | API Pressure | Use Case | Risk Level |

|---------|-------------|----------|-----------|

| \*\*1-2 concurrent\*\* | Low | Conservative approach, minimal API pressure | ✅ Low |

| \*\*3 concurrent\*\* | Medium | \*\*Recommended for most use cases\*\* (default) | ✅ Low |

| \*\*4-5 concurrent\*\* | High | Aggressive migration, may hit rate limits | ⚠️ Medium |



> \*\*⚠️ Rate Limit Warning\*\*: GitHub and Azure DevOps have API rate limits. Setting concurrency too high may result in throttling errors. Monitor for 429 (Too Many Requests) errors in logs.



\### Estimated Migration Durations



\*\*Per-Repository Duration (approximate):\*\*



| Repository Size | Commit Count | Estimated Duration |

|----------------|--------------|-------------------|

| Small | < 100 commits | 2-5 minutes |

| Medium | 100-1,000 commits | 5-15 minutes |

| Large | 1,000-10,000 commits | 15-30 minutes |

| Very Large | 10,000+ commits | 30-60 minutes |

| Huge (with LFS) | > 50,000 commits or > 5GB | 1-2 hours |



\*\*Pipeline Overhead:\*\*

\- Stage 1 (Prerequisite Validation): ~1 minute

\- Stage 2 (Pre-migration Check): ~2-5 minutes

\- Stage 4 (Validation): ~5-10 minutes

\- Stage 5 (Pipeline Rewiring): ~2-5 minutes

\- Stage 6 (Boards Integration): ~2-5 minutes

\- \*\*Manual Approval Wait Time\*\*: Variable (minutes to hours depending on availability)



\*\*Example: Migrating 50 medium-sized repositories\*\*

\- 50 repos × 10 minutes average = 500 minutes

\- With 3 concurrent migrations: 500 ÷ 3 ≈ \*\*167 minutes (~2.8 hours)\*\*

\- Plus pipeline overhead: ~15-25 minutes

\- Plus approval wait times: Variable

\- \*\*Total estimated time: 3-4 hours\*\* (excluding approval wait time)



\### Multi-Batch Migration Strategy



For large-scale migrations (100+ repos), use a multi-batch approach:



\*\*1. Prepare Separate CSV Files per Batch:\*\*



```bash

\# Batch 1: High-priority repositories

repos-batch1.csv  (50 repositories)



\# Batch 2: Medium-priority repositories

repos-batch2.csv  (50 repositories)



\# Batch 3: Low-priority repositories

repos-batch3.csv  (50 repositories)

```



\*\*2. Create Separate Branches per Batch:\*\*



```bash

\# Create branch for batch 1

git checkout -b migration/batch-1

cp repos-batch1.csv bash/repos.csv

git add bash/repos.csv

git commit -m "Migration batch 1: High-priority repositories"

git push origin migration/batch-1



\# Repeat for batch 2, 3, etc.

```



\*\*3. Run Pipelines Sequentially:\*\*

\- ✅ Run batch 1 pipeline → Wait for completion → Validate results

\- ✅ Run batch 2 pipeline → Wait for completion → Validate results

\- ✅ Run batch 3 pipeline → Wait for completion → Validate results



\*\*4. Archive Logs After Each Batch:\*\*

\- Download all artifacts (migration-logs, validation-logs, etc.)

\- Store in a central location: `\\\\shared\\migrations\\batch-1\\`

\- Create summary report for each batch



> \*\*⚠️ CRITICAL\*\*: Do NOT run multiple batches in parallel unless you are certain there is no repository overlap. Parallel migrations of the same repository will cause conflicts.



\### State Management Across Batches



\*\*Tracking Migration Progress:\*\*



1\. \*\*Maintain a master tracking spreadsheet:\*\*

&nbsp;  ```

&nbsp;  Repository Name | Batch # | Migration Date | Status | Validation Status | Notes

&nbsp;  api-service     | 1       | 2025-12-01     | ✅     | ✅                | Success

&nbsp;  web-frontend    | 1       | 2025-12-01     | ⚠️     | ⚠️                | Commit count mismatch on old branch

&nbsp;  ```



2\. \*\*Use Git tags to mark completed batches:\*\*

&nbsp;  ```bash

&nbsp;  git tag batch-1-completed -m "Batch 1: 50 repos migrated successfully"

&nbsp;  git push origin batch-1-completed

&nbsp;  ```



3\. \*\*Consolidate logs in a central repository:\*\*

&nbsp;  - Create a separate repo: `ado-github-migration-logs`

&nbsp;  - Upload all artifacts after each batch

&nbsp;  - Maintain a README with migration status



---



\## ⏸️ Manual Approval Gate Guidelines



This pipeline has \*\*three manual approval gates\*\* that pause execution until a user approves or rejects continuation. Use these guidelines to make informed decisions at each gate.



\### Gate 1: After Stage 2 (Pre-Migration Check)



\*\*Location\*\*: Between Stage 2 (Pre-migration Check) and Stage 3 (Repository Migration)



\*\*What to Review:\*\*

1\. Download the `readiness-logs` artifact

2\. Open the readiness report (CSV or text file)

3\. Look for the following indicators:



\*\*BLOCKING Issues (Must REJECT if found):\*\*

\- ❌ \*\*Active Pull Requests\*\*: Any PRs in "Active" or "In Progress" state

&nbsp; - \*\*Action\*\*: Complete, merge, or abandon PRs before proceeding

&nbsp; - \*\*Reason\*\*: PRs will NOT be migrated; work will be lost

&nbsp; 

\- ❌ \*\*Active Pipelines\*\*: Any build or release pipelines currently running

&nbsp; - \*\*Action\*\*: Wait for completion or cancel pipelines

&nbsp; - \*\*Reason\*\*: Running pipelines may interfere with migration or cause lock conflicts



\*\*WARNING Issues (Review but may proceed):\*\*

\- ⚠️ \*\*Old Branches\*\*: Branches with no commits in 6+ months

&nbsp; - \*\*Decision\*\*: Acceptable if these are inactive feature branches

&nbsp; - \*\*Action\*\*: Document which branches are old; verify after migration

&nbsp; 

\- ⚠️ \*\*Large Repository Size\*\*: Repositories > 1GB

&nbsp; - \*\*Decision\*\*: Acceptable but note for extended migration time

&nbsp; - \*\*Action\*\*: Consider reducing `maxConcurrent` to avoid timeouts



\*\*INFO Items (No action required):\*\*

\- ℹ️ Repository statistics (commit count, branch count, size)

\- ℹ️ Last commit date

\- ℹ️ Repository visibility settings



\*\*Decision Criteria:\*\*

\- ✅ \*\*APPROVE\*\*: If NO blocking issues found (active PRs or pipelines)

\- ❌ \*\*REJECT\*\*: If ANY blocking issues found; resolve issues and re-run from Stage 1



\*\*Example Approval Decision:\*\*



```

Readiness Report Summary:

\- 10 repositories scanned

\- 0 active pull requests ✅

\- 0 active pipelines ✅

\- 2 repositories with old branches (> 6 months) ⚠️

\- 1 large repository (1.2GB) ⚠️



Decision: APPROVE - No blocking issues found. Document old branches for post-migration verification.

```



---



\### Gate 2: After Stage 4 (Migration Validation)



\*\*Location\*\*: Between Stage 4 (Migration Validation) and Stage 5 (Pipeline Rewiring)



\*\*What to Review:\*\*

1\. Download the `validation-logs` artifact

2\. Open the validation summary (CSV or text file)

3\. Review branch and commit validation results



\*\*BLOCKING Issues (Must REJECT if found):\*\*

\- ❌ \*\*Missing Critical Branches\*\*: Main, master, develop, or production branches missing from GitHub

&nbsp; - \*\*Action\*\*: Re-run migration for affected repositories

&nbsp; - \*\*Reason\*\*: Critical branches must be present for production readiness

&nbsp; 

\- ❌ \*\*Commit SHA Mismatch on Main Branch\*\*: Latest commit SHA differs between ADO and GitHub on main/master/develop

&nbsp; - \*\*Action\*\*: Re-run migration; verify no commits occurred during migration

&nbsp; - \*\*Reason\*\*: Indicates incomplete or corrupted migration



\- ❌ \*\*Branch Count Mismatch > 10%\*\*: GitHub has significantly fewer branches than ADO

&nbsp; - \*\*Action\*\*: Investigate missing branches; re-run migration if necessary

&nbsp; - \*\*Reason\*\*: May indicate migration failure or branch filtering issue



\*\*WARNING Issues (Review carefully):\*\*

\- ⚠️ \*\*Commit Count Differs by < 5%\*\*: Small variance in commit count on non-critical branches

&nbsp; - \*\*Decision\*\*: Acceptable if latest commit SHA matches

&nbsp; - \*\*Reason\*\*: May be due to squashed merges or rebase history

&nbsp; 

\- ⚠️ \*\*Old Feature Branches Missing\*\*: Branches not touched in 6+ months are missing

&nbsp; - \*\*Decision\*\*: Acceptable if documented and stakeholders notified

&nbsp; - \*\*Action\*\*: Create list of missing branches for reference



\*\*INFO Items (No action required):\*\*

\- ℹ️ Total branches migrated

\- ℹ️ Total commits validated

\- ℹ️ Migration duration per repository



\*\*Decision Criteria:\*\*

\- ✅ \*\*APPROVE\*\*: If NO blocking issues on critical branches (main, develop, production)

\- ⚠️ \*\*APPROVE with Documentation\*\*: If only warnings on old feature branches

\- ❌ \*\*REJECT\*\*: If ANY blocking issues found; re-run migration and Stage 4



\*\*Example Approval Decision:\*\*



```

Validation Report Summary:

\- 10 repositories validated

\- Branch count: ADO=52, GitHub=50 ⚠️ (2 old branches missing)

\- Main branch SHA: ✅ MATCH on all repos

\- Develop branch SHA: ✅ MATCH on all repos

\- Commit count variance: < 2% on all branches ✅



Missing branches:

&nbsp; - api-service: feature/legacy-auth (last commit: 2024-01-15) ⚠️

&nbsp; - web-frontend: hotfix/old-bug (last commit: 2023-11-20) ⚠️



Decision: APPROVE with Documentation - Critical branches validated successfully. 

Document missing old branches in migration report.

```



---



\### Gate 3: After Stage 5 (Pipeline Rewiring)



\*\*Location\*\*: Between Stage 5 (Pipeline Rewiring) and Stage 6 (Boards Integration)



\*\*What to Review:\*\*

1\. Download the `rewiring-logs` artifact

2\. Open the rewiring summary (CSV or text file)

3\. Verify pipeline updates



\*\*BLOCKING Issues (Must REJECT if found):\*\*

\- ❌ \*\*Service Connection Authentication Failed\*\*: GitHub service connection cannot authenticate

&nbsp; - \*\*Action\*\*: Verify service connection PAT token is valid and has correct permissions

&nbsp; - \*\*Reason\*\*: Pipelines won't be able to access GitHub repositories

&nbsp; 

\- ❌ \*\*Pipeline YAML Syntax Errors\*\*: Pipeline definition has syntax errors after rewiring

&nbsp; - \*\*Action\*\*: Manually review and fix pipeline YAML; re-run Stage 5

&nbsp; - \*\*Reason\*\*: Pipelines will fail on next trigger

&nbsp; 

\- ❌ \*\*Repository Not Found\*\*: GitHub repository referenced in pipeline doesn't exist

&nbsp; - \*\*Action\*\*: Verify repository was migrated successfully; check naming

&nbsp; - \*\*Reason\*\*: Pipeline won't be able to clone repository



\*\*WARNING Issues (Review carefully):\*\*

\- ⚠️ \*\*Pipeline Not Tested\*\*: Pipeline hasn't been triggered post-rewiring

&nbsp; - \*\*Decision\*\*: Acceptable but plan for testing

&nbsp; - \*\*Action\*\*: Schedule pipeline test runs after approval

&nbsp; 

\- ⚠️ \*\*Service Connection Permissions\*\*: Service connection has minimal permissions

&nbsp; - \*\*Decision\*\*: Acceptable if permissions match requirements

&nbsp; - \*\*Action\*\*: Verify connection can read/write to repository



\*\*INFO Items (No action required):\*\*

\- ℹ️ Number of pipelines rewired

\- ℹ️ Service connections used

\- ℹ️ Repository mappings



\*\*Decision Criteria:\*\*

\- ✅ \*\*APPROVE\*\*: If NO blocking issues; all pipelines successfully rewired

\- ⚠️ \*\*APPROVE with Testing Plan\*\*: If warnings exist; plan to test pipelines post-migration

\- ❌ \*\*REJECT\*\*: If ANY blocking issues found; fix and re-run Stage 5



\*\*Example Approval Decision:\*\*



```

Rewiring Report Summary:

\- 5 pipelines rewired

\- Service connection: GitHub-MyCompanyGH-Connection ✅

\- Authentication: Successful ✅

\- Pipeline YAML validation: All passed ✅



Pipelines rewired:

&nbsp; - api-ci-pipeline: mycompany/Platform/api-service → mycompany-gh/platform-api ✅

&nbsp; - web-cd-pipeline: mycompany/Platform/web-frontend → mycompany-gh/platform-web ✅



Decision: APPROVE - All pipelines successfully rewired. 

Plan to test pipelines within 24 hours of migration completion.

```



---



\## 🔄 Handling Failed Migrations \& State Management



\### Understanding Migration State



\*\*Key Principles:\*\*

\- Each pipeline run is \*\*independent\*\* and stateless

\- No migration state is persisted between runs

\- Re-running the pipeline with the same `repos.csv` will \*\*attempt to re-migrate\*\* all listed repositories

\- The `gh ado2gh migrate` command is \*\*idempotent\*\* (safe to re-run)



\### Resuming a Failed Migration



\*\*Scenario\*\*: Pipeline started with 50 repos in CSV, failed at repository #23



\*\*Option 1: Resume from Failure Point (Recommended)\*\*



1\. \*\*Download and analyze logs:\*\*

&nbsp;  ```bash

&nbsp;  # Download migration-logs artifact from failed pipeline run

&nbsp;  # Extract to local directory

&nbsp;  cd ~/downloads/migration-logs

&nbsp;  ```



2\. \*\*Identify failed repositories:\*\*

&nbsp;  ```bash

&nbsp;  # Open migration-summary.csv

&nbsp;  # Look for status = "failed" or "error"

&nbsp;  ```



3\. \*\*Create retry CSV with only failed repos:\*\*

&nbsp;  ```bash

&nbsp;  # Copy header

&nbsp;  head -1 bash/repos.csv > bash/repos-retry.csv

&nbsp;  

&nbsp;  # Add only failed repositories (manual or scripted)

&nbsp;  echo "mycompany,Platform,failed-repo-1,mycompany-gh,failed-repo-1,private" >> bash/repos-retry.csv

&nbsp;  echo "mycompany,Platform,failed-repo-2,mycompany-gh,failed-repo-2,private" >> bash/repos-retry.csv

&nbsp;  ```



4\. \*\*Commit and re-run pipeline:\*\*

&nbsp;  ```bash

&nbsp;  git checkout -b migration/retry-batch

&nbsp;  cp bash/repos-retry.csv bash/repos.csv

&nbsp;  git add bash/repos.csv

&nbsp;  git commit -m "Retry failed repositories from original migration"

&nbsp;  git push origin migration/retry-batch

&nbsp;  

&nbsp;  # Run pipeline on migration/retry-batch branch

&nbsp;  ```



\*\*Option 2: Re-run Entire Batch\*\*



Safe if using `gh ado2gh migrate` (GitHub repos will be overwritten if they already exist):



```bash

\# Re-run the same pipeline with the original repos.csv

\# Previously migrated repos will show "repository already exists" but will be updated

\# Failed repos will be re-attempted

```



> ⚠️ \*\*Note\*\*: Re-running may overwrite any manual changes made to already-migrated GitHub repositories.



\*\*Option 3: Manual Investigation \& Selective Re-migration\*\*



For complex failures (e.g., authentication errors, rate limiting):



1\. \*\*Review detailed logs\*\* for root cause

2\. \*\*Fix underlying issue\*\* (e.g., refresh PAT token, increase rate limits)

3\. \*\*Test with a single repository\*\* first

4\. \*\*Re-run with full or partial CSV\*\* once issue resolved



\### Idempotency \& Safety



\*\*What is safe to re-run?\*\*



| Stage | Safe to Re-run? | Notes |

|-------|----------------|-------|

| \*\*Stage 1\*\* | ✅ Yes | Always safe; just validates CSV |

| \*\*Stage 2\*\* | ✅ Yes | Always safe; just checks readiness |

| \*\*Stage 3\*\* | ✅ Yes | Safe; `gh ado2gh migrate` is idempotent |

| \*\*Stage 4\*\* | ✅ Yes | Always safe; just validates |

| \*\*Stage 5\*\* | ⚠️ Mostly | Safe but may require manual pipeline validation |

| \*\*Stage 6\*\* | ✅ Yes | Safe; boards integration is idempotent |



\*\*What happens on re-migration?\*\*

\- \*\*GitHub repository already exists\*\*: Repository is overwritten with fresh migration from ADO

\- \*\*Commits already present\*\*: Duplicate commits are NOT created (Git uses SHA-based deduplication)

\- \*\*Branches already exist\*\*: Branches are updated to match ADO state

\- \*\*Tags already exist\*\*: Tags are updated if SHA differs



---



\## How to Update repos.csv and Run the Pipeline



\### 🛠 Updating repos.csv



1\. \*\*Edit the CSV file from you local:\*\*

&nbsp;  ```bash

&nbsp;  # Navigate to the local dir

&nbsp;  cd c:\\Users\\<username>\\factory\\ado2gh-ado-pipelines

&nbsp;  

&nbsp;  # Edit the CSV file

&nbsp;  code bash/repos.csv

&nbsp;  ```



2\. \*\*Add or modify repository entries:\*\*

&nbsp;  - Each row represents one repository to migrate

&nbsp;  - Ensure all required columns have values

&nbsp;  - Use proper CSV formatting (quote fields with commas)

&nbsp;  - Verify `gh\_repo\_visibility` is one of: `private`, `public`, `internal`



3\. \*\*Commit and push changes:\*\*

&nbsp;  ```bash

&nbsp;  git add bash/repos.csv

&nbsp;  git commit -m "Update repos.csv with new repositories"

&nbsp;  git push

&nbsp;  ```



\### ▶️ Running the Pipeline



\#### Option 1: Via Azure DevOps Web UI

1\. Navigate to: https://dev.azure.com/<org>/<project>/\_build

2\. Click on \*\*ADO to GitHub Migration Pipeline\*\*

3\. Click \*\*Run pipeline\*\* button

4\. Select branch: `main`

5\. Click \*\*Run\*\*



\#### Option 2: Via Azure CLI (Advanced)



```bash

\# Install Azure DevOps CLI extension

az extension add --name azure-devops



\# Set defaults

az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>



\# Queue a pipeline run

az pipelines run --name "ADO to GitHub Migration Pipeline" --branch main



\# Monitor pipeline run

az pipelines runs show --id <run-id>

```



> \*\*💡 Tip\*\*: For batch management, consider using separate branches per batch (see \[Multi-Batch Migration Strategy](#multi-batch-migration-strategy)).



---



\## 📄 Pipeline Run Logs



\### Accessing Pipeline Logs



\#### 1. View Logs in Azure DevOps UI

1\. Navigate to the pipeline run: https://dev.azure.com/<org>/<project>/\_build

2\. Click on the specific build number (e.g., `20251208.5`)

3\. Click on any stage or job to view logs

4\. Use the \*\*Download logs\*\* button to save all logs as a ZIP file



\#### 2. Published Artifacts

The pipeline publishes detailed logs as build artifacts:



\*\*Migration Logs\*\* (from Stage 3: Migration)

\- \*\*Artifact Name\*\*: `migration-logs`



&nbsp;\*\*Migration Validation Logs\*\* (from Stage 4: Migration Validation)

\- \*\*Artifact Name\*\*: `validation-logs`



&nbsp;\*\*Pipeline Rewiring Logs\*\* (from Stage 5: Pipeline Rewiring)

\- \*\*Artifact Name\*\*: `rewiring-logs`



&nbsp;\*\*Boards Integration Logs\*\* (from Stage 6: Boards Integration)

\- \*\*Artifact Name\*\*: `boards-integration-logs`

&nbsp; 



\*\*To download artifacts:\*\*

1\. Go to the completed pipeline run

2\. Click on the \*\*Summary\*\* or \*\*Published\*\* tab

3\. Find the \*\*Artifacts\*\* section

4\. Click on \*\*migration-logs\*\* or \*\*validation-logs\*\* or \*\*rewiring-logs\*\* or \*\*boards-integration-logs\*\* to download



---



\## 📄 Understanding Pipeline Logs



\### Stage 3: Migration Log Format



\*\*Example Log Output:\*\*



```plaintext

=== Migrating repository: mycompany/Platform/api-service ===

\[INFO] Starting migration at 2025-12-24T10:15:30Z

\[INFO] Installing gh-ado2gh extension...

\[INFO] Executing: gh ado2gh migrate-repo --ado-org mycompany --ado-team-project Platform --ado-repo api-service --github-org mycompany-gh --github-repo platform-api --visibility private

\[SUCCESS] Migration completed in 3m 42s

\[INFO] Branches migrated: 5 (main, develop, feature/auth, release/v1.0, hotfix/security)

\[INFO] Total commits: 1,247

\[INFO] Migration log saved to migration-logs/api-service-20251224-101530.log

```



\*\*Interpreting Migration Results:\*\*



| Log Level | Meaning | Action Required |

|-----------|---------|----------------|

| `\[SUCCESS]` | Repository fully migrated | ✅ No action |

| `\[WARNING]` | Migration completed with non-critical issues | ⚠️ Review details, may proceed |

| `\[ERROR]` | Migration failed | ❌ Review error, retry migration |

| `\[INFO]` | Informational message | ℹ️ For reference only |



\*\*Common Migration Log Messages:\*\*



```plaintext

\[SUCCESS] Migration completed

→ Repository successfully migrated



\[WARNING] Branch 'feature/old' has diverged history

→ Branch may have rebase/force-push history; verify manually



\[ERROR] Repository already exists and cannot be overwritten

→ GitHub repo exists; delete it or use different name



\[ERROR] Authentication failed: Bad credentials

→ PAT token is invalid or expired; refresh and retry

```



---



\### Stage 4: Validation Log Format



\*\*Example Log Output:\*\*



```plaintext

=== Validating: platform-api ===

\[CHECK] Branch count: ADO=5, GitHub=5 ✅

\[CHECK] Branch 'main': Commits=1247, SHA=a1b2c3d4 ✅ MATCH

\[CHECK] Branch 'develop': Commits=1195, SHA=e5f6g7h8 ✅ MATCH

\[CHECK] Branch 'feature/auth': Commits=23, SHA=i9j0k1l2 ✅ MATCH

\[WARNING] Branch 'release/v1.0': Commit count differs (ADO=45, GH=44) ⚠️

\[CHECK] Latest commit SHA matches ✅

\[RESULT] VALIDATION PASSED with warnings

```



\*\*Validation Decision Guide:\*\*



| Scenario | Decision | Rationale |

|----------|----------|-----------|

| All branches ✅ | ✅ APPROVE confidently | Perfect migration |

| Warnings on old branches, SHA matches | ✅ APPROVE with documentation | Acceptable variance |

| Errors on main/develop | ❌ REJECT | Critical branches must match |

| Missing critical branches | ❌ REJECT | Re-run migration |

| Commit count differs > 10% | ❌ REJECT | Investigate |



---



\## 🔧 Troubleshooting



\### Common Issues \& Solutions



\#### Issue 1: Pipeline Fails at Stage 1 - "repos.csv not found"



\*\*Symptoms:\*\*

```

\[ERROR] File not found: bash/repos.csv

Pipeline failed at Stage 1: Prerequisite Validation

```



\*\*Root Cause:\*\*

\- CSV file missing from repository

\- File in wrong location

\- File not committed/pushed to Git



\*\*Solution:\*\*

```bash

\# Verify file exists locally

ls bash/repos.csv



\# If missing, create it

touch bash/repos.csv

echo "org,teamproject,repo,github\_org,github\_repo,gh\_repo\_visibility" > bash/repos.csv



\# Add your repositories

echo "mycompany,Platform,api-service,mycompany-gh,platform-api,private" >> bash/repos.csv



\# Commit and push

git add bash/repos.csv

git commit -m "Add repos.csv"

git push

```



---



\#### Issue 2: Stage 3 Migration Times Out After 60 Minutes



\*\*Symptoms:\*\*

```

\[ERROR] Job execution time limit exceeded

Pipeline canceled by system (timeout)

```



\*\*Root Cause:\*\*

\- Repository too large (> 5GB)

\- Too many concurrent migrations

\- Network/API latency



\*\*Solution:\*\*



\*\*Option A: Reduce Batch Size\*\*

```bash

\# Split large CSV into smaller batches

\# Instead of 100 repos, try 20-30 repos per batch

```



\*\*Option B: Reduce Concurrency\*\*

```yaml

\# Edit ado2gh-migration.yml

variables:

&nbsp; - name: maxConcurrent

&nbsp;   value: 1  # Reduce from 3 to 1

```



\*\*Option C: Increase Pipeline Timeout (if allowed)\*\*

```yaml

\# Add to pipeline job definition

jobs:

\- job: Migration

&nbsp; timeoutInMinutes: 360  # 6 hours instead of default 60

```



---



\#### Issue 3: Stage 4 Validation - "Branch Count Mismatch" Error



\*\*Symptoms:\*\*

```

\[ERROR] Branch count mismatch: ADO=10, GitHub=7

\[ERROR] Missing branches: feature/legacy-api, hotfix/bug-123, release/v2.0

```



\*\*Root Cause:\*\*

\- Migration didn't complete for all branches

\- Branches have invalid names for GitHub

\- Network interruption during migration



\*\*Solution:\*\*



\*\*Step 1: Identify Missing Branches\*\*

```bash

\# Download validation-logs artifact

\# Review detailed validation report

```



\*\*Step 2: Check Branch Names\*\*

```bash

\# GitHub doesn't allow certain characters in branch names

\# Invalid: feature/my:branch, feature/my?branch

\# Valid: feature/my-branch, feature/my\_branch



\# Check ADO for branch names with special characters

```



\*\*Step 3: Re-run Migration for Affected Repos\*\*

```bash

\# Create retry CSV with only affected repositories

echo "org,teamproject,repo,github\_org,github\_repo,gh\_repo\_visibility" > bash/repos-retry.csv

echo "mycompany,Platform,api-service,mycompany-gh,platform-api,private" >> bash/repos-retry.csv



\# Commit and re-run pipeline

```



---



\#### Issue 4: Stage 5 - "Service Connection Authentication Failed"



\*\*Symptoms:\*\*

```

\[ERROR] Service connection 'GitHub-MyCompany-Connection' authentication failed

\[ERROR] HTTP 401: Unauthorized

```



\*\*Root Cause:\*\*

\- GitHub PAT token expired

\- Service connection not configured properly

\- Wrong service connection ID in pipelines.csv



\*\*Solution:\*\*



\*\*Step 1: Verify Service Connection\*\*

```bash

\# Navigate to: https://dev.azure.com/<org>/<project>/\_settings/adminservices

\# Click on the GitHub service connection

\# Click "Verify" to test authentication

```



\*\*Step 2: Update PAT Token if Expired\*\*

```bash

\# Generate new GitHub PAT (see Prerequisites section)

\# Update service connection with new token

\# Click "Verify and save"

```



\*\*Step 3: Verify Service Connection ID\*\*

```bash

\# Get ID from URL or service connection details

\# Update pipelines.csv with correct ID

```



---



\#### Issue 5: Stage 3 - "Repository Already Exists" Error



\*\*Symptoms:\*\*

```

\[ERROR] Repository 'mycompany-gh/platform-api' already exists

\[ERROR] Cannot create repository: conflict

```



\*\*Root Cause:\*\*

\- GitHub repository already exists from previous migration

\- Re-running pipeline with same CSV



\*\*Solution:\*\*



\*\*Option A: Delete Existing GitHub Repository\*\*

```bash

\# Only if you want to re-migrate completely

\# Navigate to GitHub: https://github.com/mycompany-gh/platform-api/settings

\# Scroll to "Danger Zone" → "Delete this repository"

\# Type repository name to confirm → Delete



\# Then re-run pipeline

```



\*\*Option B: Use Different Repository Name\*\*

```csv

\# Edit repos.csv

\# Change github\_repo column to a new name

org,teamproject,repo,github\_org,github\_repo,gh\_repo\_visibility

mycompany,Platform,api-service,mycompany-gh,platform-api-v2,private

```



\*\*Option C: Force Overwrite (if supported)\*\*

```bash

\# Check if gh ado2gh migrate supports --force flag

gh ado2gh migrate-repo --help | grep force



\# If supported, update migration script to include --force

```



---



\#### Issue 6: PAT Token Expired Mid-Migration



\*\*Symptoms:\*\*

```

\[ERROR] Authentication failed: Token expired

\[ERROR] HTTP 401: Unauthorized

```



\*\*Root Cause:\*\*

\- PAT token reached expiration date during long migration



\*\*Solution:\*\*



\*\*Step 1: Generate New PAT Tokens\*\*

```bash

\# GitHub: https://github.com/settings/tokens

\# ADO: https://dev.azure.com/<org>/\_usersSettings/tokens

```



\*\*Step 2: Update Variable Groups\*\*

```bash

\# Navigate to: https://dev.azure.com/<org>/<project>/\_library

\# Click on variable group: core-entauto-github-migration-secrets

\# Update GH\_PAT and ADO\_PAT values

\# Click Save

```



\*\*Step 3: Re-run Pipeline from Failure Point\*\*

```bash

\# Identify which repositories failed

\# Create retry CSV with failed repos only

\# Re-run pipeline

```



---



\#### Issue 7: API Rate Limiting - "429 Too Many Requests"



\*\*Symptoms:\*\*

```

\[ERROR] Rate limit exceeded

\[ERROR] HTTP 429: Too Many Requests

\[WARNING] Retry after 3600 seconds

```



\*\*Root Cause:\*\*

\- Too many API calls in short time (high concurrency)

\- GitHub or ADO rate limits reached



\*\*Solution:\*\*



\*\*Step 1: Reduce Concurrency\*\*

```yaml

\# Edit ado2gh-migration.yml

variables:

&nbsp; - name: maxConcurrent

&nbsp;   value: 1  # Reduce to 1

```



\*\*Step 2: Wait for Rate Limit Reset\*\*

```bash

\# GitHub rate limits reset every hour

\# Wait 60 minutes before re-running

```



\*\*Step 3: Use Different PAT Token (if available)\*\*

```bash

\# Rate limits are per-token

\# Generate new PAT token from different account

\# Update variable group

```



---



\### Getting Help \& Support



\*\*Internal Support:\*\*

\- \*\*Email\*\*: `devops-platform@mycompany.com`

\- \*\*Teams Channel\*\*: `Azure DevOps Migrations`

\- \*\*Office Hours\*\*: Monday-Friday, 9 AM - 5 PM PST



\*\*When Requesting Help, Provide:\*\*

1\. ✅ Pipeline run URL

2\. ✅ Downloaded artifacts (migration-logs, validation-logs, etc.)

3\. ✅ repos.csv file (sanitized if needed)

4\. ✅ Error messages from pipeline logs

5\. ✅ Steps already attempted



\*\*GitHub Issues:\*\*

\- For bugs or feature requests: \[Create an issue](https://github.com/yourorg/ado2gh-ado-pipelines/issues)

\- For documentation improvements: \[Submit a PR](https://github.com/yourorg/ado2gh-ado-pipelines/pulls)



---



\## ❓ Frequently Asked Questions



\### Q1: Can multiple teams run this pipeline simultaneously?



\*\*A:\*\* No, concurrent pipeline runs on the same repository can cause conflicts. \*\*Best practice:\*\*

\- Coordinate migration schedules across teams

\- Use separate CSV files per team

\- Run migrations sequentially, not in parallel

\- If absolutely necessary, ensure zero repository overlap between teams



---



\### Q2: What happens to the ADO repository after migration?



\*\*A:\*\* The ADO repository remains \*\*intact and unchanged\*\*. Migration is a \*\*copy operation\*\*, not a move.



\*\*Post-Migration:\*\*

\- ✅ ADO repository is still accessible

\- ✅ All history, branches, and commits remain in ADO

\- ⚠️ Stage 6 integrates Azure Boards, but does NOT delete ADO repo

\- ⚠️ Decommissioning ADO repositories is a \*\*manual process\*\* (out of scope for this pipeline)



\*\*Recommended Decommissioning Process:\*\*

1\. Wait 30 days after migration

2\. Verify all teams are using GitHub repository

3\. Make ADO repository read-only (disable pushes)

4\. Archive or delete ADO repository after 90-day retention period



---



\### Q3: Can I migrate repositories from multiple ADO organizations?



\*\*A:\*\* Yes, list all repositories in `repos.csv` with different `org` values.



\*\*Requirements:\*\*

\- ✅ ADO PAT token must have access to \*\*all organizations\*\*

\- ✅ List repos from different orgs in the same CSV



\*\*Example:\*\*



```csv

org,teamproject,repo,github\_org,github\_repo,gh\_repo\_visibility

mycompany,Platform,api-service,mycompany-gh,platform-api,private

anothercompany,Services,data-api,mycompany-gh,data-api,private

```



---



\### Q4: How long does a typical migration take?



\*\*A:\*\* Highly variable based on repository size and batch size.



\*\*Examples:\*\*



| Scenario | Batch Size | Avg Repo Size | Concurrency | Estimated Time |

|----------|-----------|---------------|-------------|----------------|

| Small team | 5 repos | 100 commits | 3 | 15-30 minutes |

| Medium team | 20 repos | 500 commits | 3 | 1-2 hours |

| Large team | 50 repos | 1,000 commits | 3 | 3-4 hours |

| Enterprise | 100 repos | 1,000 commits | 3 | 6-8 hours |



\*\*Note:\*\* Does NOT include manual approval wait times (can add hours or days).



---



\### Q5: Can I skip Stage 5 (Pipeline Rewiring) if I don't have pipelines?



\*\*A:\*\* No, you cannot skip stages. However, you can provide an \*\*empty `pipelines.csv`\*\* file with just the header row.



\*\*Empty pipelines.csv:\*\*



```csv

org,teamproject,pipeline,github\_org,github\_repo,serviceConnection

```



Stage 5 will complete quickly with no pipelines to rewire.



---



\### Q6: What if the GitHub organization doesn't exist yet?



\*\*A:\*\* Migration will \*\*fail\*\*. GitHub organizations must be \*\*created before running the pipeline\*\*.



\*\*Solution:\*\*

1\. Create GitHub organizations manually:

&nbsp;  - Navigate to `https://github.com/enterprises/<YOUR\_ENTERPRISE>/organizations`

&nbsp;  - Click "New organization"

&nbsp;  - Follow setup wizard

2\. Verify you have \*\*Owner\*\* or \*\*Admin\*\* role

3\. Then run the pipeline



---



\### Q7: Does this pipeline migrate pull requests?



\*\*A:\*\* No, \*\*pull requests are NOT migrated\*\*.



\*\*What Happens to PRs:\*\*

\- ❌ Active PRs in ADO will NOT be transferred to GitHub

\- ⚠️ Stage 2 (Pre-migration Check) will \*\*warn if active PRs exist\*\*

\- ✅ You must \*\*complete, merge, or abandon PRs\*\* before migration



\*\*Recommendation:\*\*

\- Complete all active PRs before migration

\- Or manually recreate PRs in GitHub after migration



---



\### Q8: Can I migrate private ADO repos to public GitHub repos?



\*\*A:\*\* Yes, use `gh\_repo\_visibility: public` in repos.csv.



\*\*Security Warning:\*\*

\- ⚠️ Migrating private to public \*\*exposes all repository content\*\*

\- ⚠️ Commit history, code, and file history become \*\*publicly accessible\*\*

\- ⚠️ \*\*Review repository for sensitive data\*\* (API keys, passwords, etc.) before migration



\*\*Recommendation:\*\*

\- Scan for secrets using tools like `git-secrets` or `gitleaks`

\- Remove sensitive data from history before migration

\- Default to `private` unless business requires public



---



\### Q9: What happens if migration fails halfway through?



\*\*A:\*\* The pipeline stops, and you can \*\*resume from the failure point\*\*.



\*\*Recovery Steps:\*\*

1\. Download `migration-logs` artifact

2\. Identify failed repositories in `migration-summary.csv`

3\. Create new CSV with only failed repos

4\. Re-run pipeline with retry CSV



See \[Handling Failed Migrations](#-handling-failed-migrations--state-management) for detailed instructions.



---



\### Q10: How do I validate that migration was successful?



\*\*A:\*\* Use the automated validation in \*\*Stage 4\*\*, plus manual verification:



\*\*Automated Validation (Stage 4):\*\*

\- ✅ Branch count comparison

\- ✅ Commit count comparison per branch

\- ✅ Latest commit SHA verification



\*\*Manual Validation:\*\*

1\. \*\*Clone GitHub repository locally\*\*:

&nbsp;  ```bash

&nbsp;  git clone https://github.com/mycompany-gh/platform-api.git

&nbsp;  cd platform-api

&nbsp;  ```



2\. \*\*Verify branches\*\*:

&nbsp;  ```bash

&nbsp;  git branch -a

&nbsp;  # Compare with ADO branches

&nbsp;  ```



3\. \*\*Verify commit history\*\*:

&nbsp;  ```bash

&nbsp;  git log --oneline --all --graph

&nbsp;  # Compare with ADO commit history

&nbsp;  ```



4\. \*\*Verify repository size\*\*:

&nbsp;  ```bash

&nbsp;  du -sh .git

&nbsp;  # Should be similar to ADO repo size

&nbsp;  ```



5\. \*\*Test build/pipelines\*\* (if applicable)



---



\## 📋 Migration Runbook



Use this operational checklist to plan and execute migrations.



\### Pre-Migration (T-1 Week)



\*\*Communication:\*\*

\- \[ ] Announce migration window to repository owners

\- \[ ] Create communication plan (email template, Teams message, etc.)

\- \[ ] Schedule migration review meeting



\*\*Preparation:\*\*

\- \[ ] Validate all target GitHub organizations exist

\- \[ ] Verify GitHub PAT and ADO PAT tokens are valid and unexpired

\- \[ ] Create variable groups with PAT tokens

\- \[ ] Create GitHub service connections in ADO

\- \[ ] Prepare `repos.csv` with target repositories

\- \[ ] Prepare `pipelines.csv` for pipeline rewiring (if applicable)



\*\*Testing:\*\*

\- \[ ] Test pipeline with 1-3 sample repositories (non-production)

\- \[ ] Verify validation logs and migration logs

\- \[ ] Confirm approval gates work as expected

\- \[ ] Test boards integration (Stage 6)



\*\*Stakeholder Alignment:\*\*

\- \[ ] Get approval from repository owners for migration window

\- \[ ] Identify migration approvers for approval gates

\- \[ ] Document rollback plan (if needed)



---



\### Migration Day (T-0)



\*\*Pre-Migration Check:\*\*

\- \[ ] Lock ADO repositories (optional, prevents commits during migration)

&nbsp; - Navigate to ADO repo settings → Policies → Add policy to block pushes

\- \[ ] Verify no active PRs in ADO (or plan to complete them)

\- \[ ] Verify no active pipelines in ADO (or wait for completion)

\- \[ ] Notify stakeholders migration is starting



\*\*Pipeline Execution:\*\*

\- \[ ] Commit `repos.csv` to repository and push

\- \[ ] Run pipeline (via ADO UI or CLI)

\- \[ ] Monitor \*\*Stage 1\*\* (Prerequisite Validation) - ~1 minute

&nbsp; - Verify CSV format is valid

&nbsp; - Note repository count

\- \[ ] Monitor \*\*Stage 2\*\* (Pre-Migration Check) - ~2-5 minutes

&nbsp; - Download `readiness-logs` artifact

&nbsp; - Review for active PRs/pipelines

&nbsp; - \*\*Approval Gate\*\*: Approve/reject based on readiness report

\- \[ ] Monitor \*\*Stage 3\*\* (Repository Migration) - ~Variable

&nbsp; - Watch for errors in pipeline logs

&nbsp; - Download `migration-logs` artifact when complete

&nbsp; - Verify migration summary shows successes

\- \[ ] Monitor \*\*Stage 4\*\* (Migration Validation) - ~5-10 minutes

&nbsp; - Download `validation-logs` artifact

&nbsp; - Review branch and commit validation results

&nbsp; - \*\*Approval Gate\*\*: Approve/reject based on validation report

\- \[ ] Monitor \*\*Stage 5\*\* (Pipeline Rewiring) - ~2-5 minutes

&nbsp; - Download `rewiring-logs` artifact

&nbsp; - Verify pipelines rewired successfully

&nbsp; - \*\*Approval Gate\*\*: Approve/reject based on rewiring report

\- \[ ] Monitor \*\*Stage 6\*\* (Boards Integration) - ~2-5 minutes

&nbsp; - Download `boards-integration-logs` artifact

&nbsp; - Verify Azure Boards integration successful



\*\*Post-Pipeline:\*\*

\- \[ ] Verify all repositories accessible in GitHub

\- \[ ] Test sample repository clone from GitHub

\- \[ ] Test CI/CD pipeline trigger (if applicable)

\- \[ ] Verify Azure Boards AB# linking works



---



\### Post-Migration (T+1 Day)



\*\*Validation:\*\*

\- \[ ] Clone each migrated repository and verify branches

\- \[ ] Run test builds/pipelines on GitHub

\- \[ ] Verify commit history integrity (spot-check key commits)

\- \[ ] Verify repository permissions and team access in GitHub



\*\*Communication:\*\*

\- \[ ] Send completion notification to stakeholders

&nbsp; - Include migration summary (repos migrated, validation status)

&nbsp; - Provide GitHub repository URLs

&nbsp; - Document any issues or warnings

\- \[ ] Update internal documentation with new GitHub repo links

\- \[ ] Create post-migration report



\*\*Artifact Management:\*\*

\- \[ ] Archive all pipeline logs (migration, validation, rewiring, boards)

\- \[ ] Store logs in central location: `\\\\shared\\migrations\\2025-12-24\\`

\- \[ ] Create summary spreadsheet with migration status per repo



\*\*ADO Repository Decommissioning (T+30 Days):\*\*

\- \[ ] Verify all teams using GitHub repository (not ADO)

\- \[ ] Make ADO repository \*\*read-only\*\*:

&nbsp; - Settings → Policies → Deny write permissions

&nbsp; - Add banner: "This repo has been migrated to GitHub: \[link]"

\- \[ ] Schedule ADO repository archival or deletion (T+90 days)



---



\## ⚠️ Scope \& Limitations



\### What This Pipeline DOES Migrate



✅ \*\*Git Repository Content\*\*

\- All branches (main, develop, feature, release, hotfix, etc.)

\- All tags (version tags, release tags)

\- Complete commit history and authorship

\- Git LFS objects (if present in ADO)



✅ \*\*Repository Metadata\*\*

\- Repository description (if supported by migration tool)

\- Repository settings (visibility: public/private/internal)



---



\### What This Pipeline DOES NOT Migrate



❌ \*\*Pull Requests\*\*

\- Active or closed PRs remain in ADO

\- PR comments, reviews, and approvals are NOT migrated

\- \*\*Workaround\*\*: Complete all active PRs before migration or manually recreate in GitHub



❌ \*\*Azure DevOps Wikis\*\*

\- Wiki content stays in ADO

\- \*\*Workaround\*\*: Manually export wiki as Markdown and create GitHub Wiki or repo



❌ \*\*Work Items\*\*

\- Work items remain in Azure Boards

\- Stage 6 integrates Azure Boards with GitHub (AB# linking)

\- Work items are NOT migrated to GitHub Issues



❌ \*\*Build/Release History\*\*

\- Pipeline execution history stays in ADO

\- Only pipeline \*\*definitions\*\* are rewired (Stage 5)

\- Historical build logs are NOT migrated



❌ \*\*Azure Artifacts/Packages\*\*

\- NuGet, npm, Maven packages remain in Azure Artifacts

\- \*\*Workaround\*\*: Publish packages to GitHub Packages separately



❌ \*\*Repository Permissions\*\*

\- ADO repo permissions are NOT transferred to GitHub

\- \*\*Workaround\*\*: Configure GitHub teams and permissions manually post-migration



❌ \*\*Branch Policies\*\*

\- ADO branch policies (required reviewers, build validation) are NOT migrated

\- \*\*Workaround\*\*: Configure GitHub branch protection rules manually



---



\### Known Limitations



\*\*Technical Limitations:\*\*



| Limitation | Description | Impact |

|-----------|-------------|--------|

| \*\*Max Concurrent Migrations\*\* | 5 (API rate limit protection) | Migrations slower for large batches |

| \*\*Max Recommended Batch Size\*\* | 100 repositories per run | Large migrations require multiple batches |

| \*\*Pipeline Timeout\*\* | 6 hours (configurable) | Very large repos may timeout |

| \*\*Repository Size Limit\*\* | Recommended < 10GB per repo | Larger repos may timeout or fail |

| \*\*Branch Name Restrictions\*\* | GitHub disallows certain characters (`:`, `?`, `\*`) | Branches with special chars may fail |



\*\*Permission Requirements:\*\*



| Resource | Minimum Required Permission | Notes |

|----------|---------------------------|-------|

| \*\*ADO Project\*\* | Project Administrator | For service connection management |

| \*\*GitHub Organization\*\* | Owner or Admin | For repository creation |

| \*\*GitHub Service Connection\*\* | Contributor | For pipeline rewiring |

| \*\*Azure Pipelines\*\* | Build Administrator | For running pipelines |



---



\### When NOT to Use This Pipeline



❌ \*\*Single Repository Migration\*\*

\- \*\*Reason\*\*: Too much overhead for one repo

\- \*\*Alternative\*\*: Use `gh ado2gh migrate-repo` CLI command directly



❌ \*\*Repositories with Complex Monorepo Dependencies\*\*

\- \*\*Reason\*\*: Custom transformations required

\- \*\*Alternative\*\*: Manual migration with Git subtree/submodule management



❌ \*\*Migrations Requiring Commit History Filtering\*\*

\- \*\*Reason\*\*: Pipeline migrates full history as-is

\- \*\*Alternative\*\*: Use `git filter-repo` or BFG Repo-Cleaner before migration



❌ \*\*Repositories > 10GB\*\*

\- \*\*Reason\*\*: May exceed pipeline timeout limits

\- \*\*Alternative\*\*: Migrate individually with increased timeout or use Git LFS cleanup



❌ \*\*Organizations Not Ready for Self-Service\*\*

\- \*\*Reason\*\*: Requires understanding of Git, pipelines, and DevOps concepts

\- \*\*Alternative\*\*: Coordinate with centralized migration team



---



\## 📂 Pipeline Structure



```

ado2gh-ado-pipelines/

├── ado2gh-migration.yml                          # Main pipeline definition (6 stages)

├── bash/

│   ├── 1\_migration\_readiness\_check.sh           # Stage 2: Readiness validation script

│   ├── 2\_migration.sh                           # Stage 3: Migration execution script

│   ├── 3\_post\_migration\_validation.sh           # Stage 4: Post-migration validation script

│   ├── 4\_rewire\_pipeline.sh                     # Stage 5: Pipeline rewiring script

│   ├── 5\_boards\_integration.sh                  # Stage 6: Azure Boards integration script

│   ├── repos.csv                                # Repository list (required)

│   └── pipelines.csv                            # Pipeline list for rewiring (required for Stage 5)

├── .gitattributes                                # Git line ending configuration

└── README.md                                     # This file

```



\## 📄 License





MIT License



Copyright (c) 2025 Vamsi Cherukuri <vamsicherukuri@hotmail.com>



Permission is hereby granted, free of charge, to any person obtaining a copy

of this software and associated documentation files (the "Software"), to deal

in the Software without restriction, including without limitation the rights

to use, copy, modify, merge, publish, distribute, sublicense, and/or sell

copies of the Software, and to permit persons to whom the Software is

furnished to do so, subject to the following conditions:



The above copyright notice and this permission notice shall be included in all

copies or substantial portions of the Software.



THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR

IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,

FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE

AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER

LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,

OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE

SOFTWARE.

