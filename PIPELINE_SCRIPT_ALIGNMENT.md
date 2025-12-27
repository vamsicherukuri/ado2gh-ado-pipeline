# Pipeline-Script Behavior Alignment
**Date:** December 27, 2025  
**Status:** ✅ Fully Aligned

---

## Executive Summary

The pipeline YAML and bash scripts are now **fully aligned** with complementary behavior:
- **Scripts** handle business logic and exit with appropriate codes
- **Pipeline** respects those exit codes and propagates failures correctly
- **No contradictions** between YAML conditions and script behavior

---

## ✅ Alignment Matrix

| Stage | YAML Condition | Script Exit Behavior | `continueOnError` | **Status** |
|-------|----------------|----------------------|-------------------|------------|
| **Stage 1: Prerequisites** | Implicit (runs if queue) | exit 1 on validation failure | ❌ No | ✅ **Aligned** |
| **Stage 2: Readiness** | Depends on Stage 1 success | N/A (manual approval) | N/A | ✅ **Aligned** |
| **Stage 3: Migration** | Depends on Stage 2 success | exit 0 (all succeed)<br>exit 1 (all fail)<br>exit 0 + SucceededWithIssues (partial) | ❌ **Removed** | ✅ **Aligned** |
| **Stage 4: Validation** | Runs if Migration = Succeeded/SucceededWithIssues | exit 0 (all succeed)<br>exit 1 (all fail or no repos)<br>exit 0 + SucceededWithIssues (partial) | ❌ **Removed** | ✅ **Aligned** |
| **Stage 5: Rewiring** | Runs if Validation = Succeeded/SucceededWithIssues | exit 1 (no repos)<br>exit 0 + SucceededWithIssues (partial) | ❌ **Removed** | ✅ **Aligned** |
| **Stage 6: Boards** | Runs if Rewiring = Succeeded/SucceededWithIssues **AND** param=true | exit 1 (no repos or all fail)<br>exit 0 + SucceededWithIssues (partial) | ❌ **Removed** | ✅ **Aligned** |
| **Stage 7: Disable** | Runs if Boards = Succeeded/SucceededWithIssues/Skipped **AND** param=true | exit 1 (no repos) | ❌ **Removed** | ✅ **Aligned** |
| **Stage 8: Summary** | always() | exit 0 (always) | N/A | ✅ **Aligned** |

---

## 📊 Detailed Behavior Analysis

### **Stage 3: Migration**

**YAML:**
```yaml
dependsOn: MigrationReadinessCheck
condition: (implicit - runs if previous succeeded)
continueOnError: NO ← REMOVED
```

**Script Logic:**
```bash
if (( ${#FAILED[@]} == 0 )); then
  exit 0  # All successful
elif (( ${#MIGRATED[@]} == 0 )); then
  exit 1  # All failed
else
  task.complete result=SucceededWithIssues
  exit 0  # Partial success
fi
```

**Alignment:**
- ✅ All fail → exit 1 → Job fails → Stage fails → Stage 4 doesn't run
- ✅ All succeed → exit 0 → Job succeeds → Stage succeeds → Stage 4 runs
- ✅ Partial → SucceededWithIssues → Stage 4 condition met → Stage 4 runs

---

### **Stage 4: Validation**

**YAML:**
```yaml
dependsOn: Migration
condition: in(dependencies.Migration.result, 'Succeeded', 'SucceededWithIssues')
continueOnError: NO ← REMOVED
```

**Script Pre-Check:**
```bash
# Check if any repos succeeded migration
success_count=$(tail -n +2 "$csv_path" | grep -c ",Success$" || true)
if [ "$success_count" -eq 0 ]; then
  exit 1  # No repos to validate
fi
```

**Script Exit Logic:**
```bash
if [ $VALIDATION_SUCCESSES -eq 0 ] && [ $VALIDATION_FAILURES -eq 0 ]; then
  exit 1  # No repos processed
elif [ $VALIDATION_SUCCESSES -eq 0 ]; then
  exit 1  # All failed validation
elif [ $VALIDATION_FAILURES -eq 0 ]; then
  exit 0  # All succeeded
else
  task.complete result=SucceededWithIssues
  exit 0  # Partial success
fi
```

**Alignment:**
- ✅ Stage only runs if Migration succeeded/partial (condition)
- ✅ If Migration succeeded, repos_with_status.csv has Success entries → script processes them
- ✅ If script finds no Success repos → exits 1 → job fails → Stage 5 doesn't run
- ✅ Script handles partial success correctly → Stage 5 can run

**Why This Works:**
- Migration "SucceededWithIssues" means at least 1 repo succeeded
- repos_with_status.csv will have Success entries
- Validation script will find them and process
- No contradiction possible

---

### **Stage 5: Rewiring**

**YAML:**
```yaml
dependsOn: PostMigrationValidation
condition: in(dependencies.PostMigrationValidation.result, 'Succeeded', 'SucceededWithIssues')
continueOnError: NO ← REMOVED
```

**Script Pre-Check:**
```bash
# In load_migrated_repos()
if [ ${#MIGRATED_REPOS[@]} -eq 0 ]; then
  echo "##[error]No successfully migrated repositories to rewire"
  exit 1
fi
```

**Alignment:**
- ✅ Stage only runs if Validation succeeded/partial
- ✅ Script loads repos from repos_with_status.csv (filtered by Success)
- ✅ If no Success repos → exits 1 → job fails
- ✅ Partial success handled with SucceededWithIssues

---

### **Stage 6: Azure Boards Integration**

**YAML:**
```yaml
dependsOn: PipelineRewiring
condition: |
  and(
    eq('${{ parameters.runAzureBoardsIntegration }}', true),
    in(dependencies.PipelineRewiring.result, 'Succeeded', 'SucceededWithIssues')
  )
continueOnError: NO ← REMOVED
```

**Script Pre-Check:**
```bash
# In validate_prerequisites()
success_count=$(tail -n +2 "repos_with_status.csv" | grep -c ",Success$" || true)
if [ "$success_count" -eq 0 ]; then
  exit 1
fi
```

**Script Exit Logic:**
```bash
if [ $TOTAL_REPOS -eq 0 ]; then
  exit 1  # No repos processed
elif [ $SUCCESSFUL_INTEGRATIONS -eq 0 ]; then
  exit 1  # All failed
elif [ $FAILED_INTEGRATIONS -gt 0 ]; then
  task.complete result=SucceededWithIssues
  exit 0  # Partial success
else
  exit 0  # All succeeded
fi
```

**Alignment:**
- ✅ Stage only runs if parameter=true AND Rewiring succeeded/partial
- ✅ **Changed from previous:** No longer runs on Failed/Canceled
- ✅ Script validates Success repos exist before processing
- ✅ Partial success properly handled

**Why Changed:**
- Previous condition allowed running even on failures
- With `continueOnError` removed, this would cause unnecessary failure
- New condition: Only run if there's something to integrate

---

### **Stage 7: Disable ADO Repositories**

**YAML:**
```yaml
dependsOn: AzureBoardsIntegration
condition: |
  and(
    eq('${{ parameters.runDisableADORepos }}', true),
    in(dependencies.AzureBoardsIntegration.result, 'Succeeded', 'SucceededWithIssues', 'Skipped')
  )
continueOnError: NO ← REMOVED
```

**Script Pre-Check:**
```bash
# In validate_prerequisites()
success_count=$(tail -n +2 "repos_with_status.csv" | grep -c ",Success$" || true)
if [ "$success_count" -eq 0 ]; then
  exit 1
fi
```

**Alignment:**
- ✅ Runs if parameter=true AND (Boards succeeded/partial OR Boards was skipped)
- ✅ **Includes 'Skipped'** because Boards is optional (parameter-controlled)
- ✅ If Boards was skipped (param=false), Disable can still run
- ✅ Script validates Success repos exist before disabling

**Why 'Skipped' Included:**
- User might skip Boards (param=false) but want to Disable repos
- Both stages are independent, optional operations
- Both check for successful migrations independently

---

## 🔄 Complete Flow Scenarios

### **Scenario 1: All Repos Fail Migration**

```
Stage 1: Prerequisites → Succeeded
Stage 2: Readiness    → Succeeded (manual approval)
Stage 3: Migration    → FAILED (exit 1, no continueOnError)
Stage 4: Validation   → SKIPPED (condition not met: Migration ≠ Succeeded/SucceededWithIssues)
Stage 5: Rewiring     → SKIPPED (condition not met: Validation ≠ Succeeded/SucceededWithIssues)
Stage 6: Boards       → SKIPPED (condition not met: Rewiring ≠ Succeeded/SucceededWithIssues)
Stage 7: Disable      → SKIPPED (condition not met: Boards ≠ Succeeded/SucceededWithIssues/Skipped)
Stage 8: Summary      → Succeeded (always runs)
```

**Result:** ✅ Pipeline stops at Stage 3, no downstream processing

---

### **Scenario 2: Partial Migration Success (2/5 succeed)**

```
Stage 1: Prerequisites → Succeeded
Stage 2: Readiness    → Succeeded
Stage 3: Migration    → SucceededWithIssues (task.complete, exit 0)
  └─ repos_with_status.csv: 2 Success, 3 Failed
Stage 4: Validation   → Runs (condition met)
  └─ Script finds 2 Success repos, validates them
  └─ 1 validation succeeds, 1 fails
  └─ SucceededWithIssues
Stage 5: Rewiring     → Runs (condition met)
  └─ Loads 2 Success repos
  └─ Rewires 1 successfully, 1 fails
  └─ SucceededWithIssues
Stage 6: Boards       → Runs if param=true (condition met)
  └─ Finds 2 Success repos
  └─ Integrates them
Stage 7: Disable      → Runs if param=true (condition met)
  └─ Finds 2 Success repos
  └─ Disables them in ADO
Stage 8: Summary      → Succeeded
```

**Result:** ✅ Pipeline processes successful repos through entire flow

---

### **Scenario 3: All Succeed, Skip Boards, Run Disable**

```
Parameters:
  runAzureBoardsIntegration: false
  runDisableADORepos: true

Stage 1-5: All Succeeded
Stage 6: Boards       → SKIPPED (param=false)
Stage 7: Disable      → Runs (Boards=Skipped, which is in condition)
  └─ Script validates Success repos exist
  └─ Disables all migrated repos
Stage 8: Summary      → Succeeded
```

**Result:** ✅ Can skip Boards but still Disable repos

---

### **Scenario 4: Validation Fails All Repos**

```
Stage 1-3: Succeeded (all repos migrated)
Stage 4: Validation   → FAILED
  └─ Script finds repos in CSV
  └─ All validations fail (e.g., branch count mismatch)
  └─ exit 1 (no continueOnError)
Stage 5: Rewiring     → SKIPPED (Validation failed)
Stage 6: Boards       → SKIPPED
Stage 7: Disable      → SKIPPED
Stage 8: Summary      → Succeeded (shows Validation failed)
```

**Result:** ✅ Pipeline stops at validation failure, doesn't proceed with bad migrations

---

## 🛡️ Safety Mechanisms

### **1. Pre-Flight Checks**
Every script validates prerequisites before processing:
- repos_with_status.csv exists
- Success count > 0
- Required environment variables set

**Prevents:** Attempting operations with no valid data

### **2. Fail-Fast on Total Failure**
Scripts exit with code 1 when:
- No repositories to process
- All operations fail (0 successes)
- Critical errors (missing files, auth failures)

**Prevents:** False success indicators

### **3. Partial Success Handling**
Scripts use `task.complete result=SucceededWithIssues` when:
- Some operations succeed
- Some operations fail

**Allows:** Pipeline to continue with successful repos while logging failures

### **4. Stage Conditions**
YAML conditions ensure stages only run when:
- Previous stage succeeded or had partial success
- Optional parameters are enabled
- Dependencies are met

**Prevents:** Running stages with no valid input

### **5. No continueOnError Abuse**
Removed from all main execution tasks:
- Migration execution
- Validation execution
- Rewiring execution
- Boards integration execution
- Disable repos execution

**Ensures:** Exit codes properly propagate to stage results

### **6. Artifact Publishing Always Runs**
Artifact tasks have `continueOnError: true`:
- Logs get published even on failure
- Results CSV gets published even on partial failure

**Allows:** Debugging and downstream consumption

---

## 📋 Validation Checklist

- [x] Migration task exit codes properly fail/succeed the job
- [x] Validation only runs when Migration has successes
- [x] Validation task failures properly fail the stage
- [x] Rewiring only runs when Validation succeeded/partial
- [x] Rewiring validates MIGRATED_REPOS array is not empty
- [x] Boards only runs when enabled AND Rewiring succeeded/partial
- [x] Boards validates Success repos before processing
- [x] Disable only runs when enabled AND (Boards succeeded/partial OR skipped)
- [x] Disable validates Success repos before disabling
- [x] Summary always runs to show final status
- [x] All scripts have consistent Success/Failed/Partial logic
- [x] No contradictions between YAML conditions and script behavior
- [x] Partial success propagates correctly through stages
- [x] Total failure stops the pipeline at the failure point

---

## 🔧 Key Takeaways

### **What Changed:**

**Before:**
- `continueOnError: true` everywhere
- Scripts could fail but stages would succeed
- Contradictory behavior between YAML and scripts
- Pipeline would run through all stages even on total failure

**After:**
- `continueOnError` only on artifact publishing
- Script exit codes directly control stage results
- YAML conditions aligned with script logic
- Pipeline stops at first total failure
- Partial success propagates correctly

### **Design Principles:**

1. **Scripts own the business logic** - They decide when to fail/succeed/partial
2. **Pipeline respects script decisions** - No `continueOnError` overrides
3. **Conditions are defensive** - Stages check if previous succeeded before running
4. **Fail fast on total failure** - Don't waste time processing nothing
5. **Continue gracefully on partial** - Process what succeeded, log what failed
6. **Always publish artifacts** - Logs and results needed for debugging

---

**Status:** ✅ **Pipeline and scripts are fully aligned and complementary**
