# Pipeline Behavior Fixes - All Migration Failures
**Date:** December 27, 2025  
**Issue:** Downstream stages triggered even when ALL repos failed migration

---

## 🔴 Critical Issues Fixed

### **Issue 1: Migration Stage Doesn't Fail When All Repos Fail**

**Problem:**
- `continueOnError: true` on Migration task (Line 219)
- When ALL repos fail, script exits with code 1
- But the task doesn't fail the job due to `continueOnError`
- Migration stage shows "Succeeded" → downstream stages run

**Fix:**
- **Removed** `continueOnError: true` from Migration task
- Now when all repos fail (exit 1), the job properly fails
- Downstream stages won't run when Migration stage = Failed

**Impact:**
- ✅ Stage 3 (Migration) now properly fails when ALL repos fail
- ✅ Stages 4-7 won't run if all migrations fail
- ✅ Partial success still works (SucceededWithIssues)

---

### **Issue 2: Validation Runs Even With No Successful Migrations**

**Problem:**
- Script checked if file exists, but not if it contains any successes
- Would process empty list and exit 0
- No validation actually performed

**Fix Added to bash/3_post_migration_validation.sh:**
```bash
# Check if any repos succeeded migration
local success_count
success_count=$(tail -n +2 "$csv_path" | grep -c ",Success$" || true)
if [ "$success_count" -eq 0 ]; then
    echo "##[error]No successfully migrated repositories to validate"
    exit 1
fi
```

**Exit Logic Enhanced:**
```bash
# Fail if no repositories were processed at all
if [ $VALIDATION_SUCCESSES -eq 0 ] && [ $VALIDATION_FAILURES -eq 0 ]; then
    exit 1
fi

# Fail if all validations failed
if [ $VALIDATION_SUCCESSES -eq 0 ]; then
    exit 1
fi
```

---

### **Issue 3: Rewiring Runs With No Migrated Repos**

**Problem:**
- `load_migrated_repos()` loads empty `MIGRATED_REPOS` array
- Script continues and processes nothing
- Exits successfully

**Fix Added to bash/4_rewire_pipeline.sh:**
```bash
# Exit if no repos migrated successfully
if [ ${#MIGRATED_REPOS[@]} -eq 0 ]; then
    echo "##[error]No successfully migrated repositories to rewire"
    exit 1
fi
```

---

### **Issue 4: Boards Integration Always Exits 0**

**Problem:**
- Script had `# Always exit 0 to allow pipeline to continue`
- Even with no repos, it exits successfully

**Fix Added to bash/5_boards_integration.sh:**
```bash
# Check if any repos succeeded migration (in validate_prerequisites)
success_count=$(tail -n +2 "repos_with_status.csv" | grep -c ",Success$" || true)
if [ "$success_count" -eq 0 ]; then
    echo "##[error]No successfully migrated repositories"
    exit 1
fi

# Handle integration results (in print_summary)
if [ $TOTAL_REPOS -eq 0 ]; then
    exit 1
elif [ $SUCCESSFUL_INTEGRATIONS -eq 0 ]; then
    exit 1
fi
```

---

### **Issue 5: Disable ADO Repos Doesn't Check for Successes**

**Problem:**
- Only checked if file exists
- Didn't verify it has successful migrations

**Fix Added to bash/6_disable_ado_repo.sh:**
```bash
# Check if any repos succeeded migration
success_count=$(tail -n +2 "repos_with_status.csv" | grep -c ",Success$" || true)
if [ "$success_count" -eq 0 ]; then
    echo "##[error]No successfully migrated repositories"
    exit 1
fi
```

---

## ✅ New Pipeline Behavior

### **Scenario 1: ALL Repos Fail Migration**

**Before:**
1. Stage 3: Migration → "Succeeded" (due to continueOnError)
2. Stage 4: Validation → "Succeeded" (processed 0, exits 0)
3. Stage 5: Rewiring → "Succeeded" (processed 0, exits 0)
4. Stage 6: Boards → "Succeeded" (processed 0, exits 0)
5. Stage 7: Disable → "Succeeded" (processed 0, exits 0)

**After:**
1. Stage 3: Migration → **"Failed"** (exit 1, no continueOnError)
2. Stage 4: Validation → **Skipped** (condition not met)
3. Stage 5: Rewiring → **Skipped** (condition not met)
4. Stage 6: Boards → **Skipped** (condition not met)
5. Stage 7: Disable → **Skipped** (condition not met)
6. Stage 8: Summary → Runs (condition: always())

✅ **Pipeline stops after Stage 3 when all fail**

---

### **Scenario 2: SOME Repos Fail (Partial Success)**

**Before & After (same behavior):**
1. Stage 3: Migration → "SucceededWithIssues" (task.complete)
2. Stage 4: Validation → Runs (condition met)
3. Stage 5: Rewiring → Runs (condition met)
4. Stage 6: Boards → Runs if enabled
5. Stage 7: Disable → Runs if enabled
6. Stage 8: Summary → Runs

✅ **Partial success continues as expected**

---

### **Scenario 3: All Repos Succeed**

**Before & After (same behavior):**
1. Stage 3: Migration → "Succeeded"
2. Stage 4: Validation → Runs
3. Stage 5: Rewiring → Runs
4. Stage 6: Boards → Runs if enabled
5. Stage 7: Disable → Runs if enabled
6. Stage 8: Summary → Runs

✅ **Full success continues normally**

---

## 📋 Files Modified

| File | Changes |
|------|---------|
| ado2gh-migration.yml | Removed `continueOnError: true` from Migration task |
| bash/3_post_migration_validation.sh | Added success count check + enhanced exit logic |
| bash/4_rewire_pipeline.sh | Added zero-repo check in `load_migrated_repos()` |
| bash/5_boards_integration.sh | Added success count check + fixed exit logic |
| bash/6_disable_ado_repo.sh | Added success count check in prerequisites |

---

## 🧪 Testing Recommendations

### **Test Case 1: All Repos Fail**
```csv
# repos.csv with invalid/non-existent repos
org,teamproject,repo,github_org,github_repo,gh_repo_visibility
contoso,project1,invalid-repo,github-org,test-repo,private
```

**Expected Result:**
- Stage 3 fails with exit code 1
- Stages 4-7 are skipped
- Stage 8 (Summary) shows Stage 3 as "Failed"

### **Test Case 2: Partial Success**
```csv
# Mix of valid and invalid repos
org,teamproject,repo,github_org,github_repo,gh_repo_visibility
contoso,project1,valid-repo,github-org,test-repo1,private
contoso,project1,invalid-repo,github-org,test-repo2,private
```

**Expected Result:**
- Stage 3 completes with "SucceededWithIssues"
- repos_with_status.csv shows 1 Success, 1 Failed
- Stage 4 validates only the successful repo
- Stages 5-7 process only the successful repo

### **Test Case 3: All Succeed**
```csv
# All valid repos
org,teamproject,repo,github_org,github_repo,gh_repo_visibility
contoso,project1,repo1,github-org,test-repo1,private
contoso,project1,repo2,github-org,test-repo2,private
```

**Expected Result:**
- All stages succeed
- All repos processed through entire pipeline

---

## 🔍 Stage Dependencies Review

### **Current Dependency Chain:**

```yaml
Stage 1: PrerequisiteValidation
  └─ No dependencies

Stage 2: MigrationReadinessCheck
  └─ dependsOn: PrerequisiteValidation
  └─ condition: (implicit - runs if previous succeeded)

Stage 3: Migration
  └─ dependsOn: MigrationReadinessCheck
  └─ condition: (implicit - runs if previous succeeded)

Stage 4: PostMigrationValidation
  └─ dependsOn: Migration
  └─ condition: in(dependencies.Migration.result, 'Succeeded', 'SucceededWithIssues')
  ✅ CORRECT: Runs on success or partial success

Stage 5: PipelineRewiring
  └─ dependsOn: PostMigrationValidation
  └─ condition: in(dependencies.PostMigrationValidation.result, 'Succeeded', 'SucceededWithIssues')
  ✅ CORRECT: Runs on success or partial success

Stage 6: AzureBoardsIntegration
  └─ dependsOn: PipelineRewiring
  └─ condition: and(
       eq('${{ parameters.runAzureBoardsIntegration }}', true),
       in(dependencies.PipelineRewiring.result, 'Succeeded', 'SucceededWithIssues', 'Failed', 'Skipped', 'Canceled')
     )
  ✅ CORRECT: Runs even if previous failed (optional stage)

Stage 7: DisableADORepositories
  └─ dependsOn: AzureBoardsIntegration
  └─ condition: and(
       eq('${{ parameters.runDisableADORepos }}', true),
       in(dependencies.AzureBoardsIntegration.result, 'Succeeded', 'SucceededWithIssues', 'Failed', 'Skipped', 'Canceled')
     )
  ✅ CORRECT: Runs even if previous failed (optional stage)

Stage 8: PipelineCompletion
  └─ dependsOn: All previous stages
  └─ condition: always()
  ✅ CORRECT: Always runs to show summary
```

**Note:** Stages 6 & 7 are optional and allow previous failures because they're independent operations. However, the scripts themselves now validate that there are successful migrations before proceeding.

---

## 📝 Summary

**Before:** Pipeline would run all stages even when ALL repos failed migration, processing empty lists and showing false success.

**After:** Pipeline properly fails at Stage 3 when all repos fail, preventing downstream stages from running unnecessarily.

**Key Principle:** 
- **Fail fast** when there's nothing to process
- **Continue gracefully** when there's partial success
- **Validate inputs** at each stage before processing

---

**Status:** ✅ **All fixes applied and ready for testing**
