#!/usr/bin/env bash

################################################################################
# Disable ADO Repository Script
# 
# This script disables Azure DevOps repositories after successful migration
# to GitHub Enterprise.
#
# Prerequisites:
#   - repos.csv with required columns (org, teamproject, repo)
#   - ADO_PAT environment variable (Azure DevOps PAT)
#   - GH_PAT environment variable (GitHub Personal Access Token)
#   - gh CLI installed with ado2gh extension
#
# Usage:
#   ./6_disable_ado_repo.sh
#
# WARNING: This action disables repositories in Azure DevOps!
#          Only run this after confirming successful migration.
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters for summary
TOTAL_REPOS=0
SUCCESSFUL_DISABLES=0
FAILED_DISABLES=0

# Log file
LOG_FILE="disable-ado-repos-$(date +%Y%m%d-%H%M%S).log"

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo "" | tee -a "$LOG_FILE"
    echo "==========================================================================" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
    echo "==========================================================================" | tee -a "$LOG_FILE"
}

################################################################################
# Validation Functions
################################################################################

validate_prerequisites() {
    log_section "VALIDATING PREREQUISITES"
    
    # Check if repos_with_status.csv exists
    if [ ! -f "repos_with_status.csv" ]; then
        log_error "repos_with_status.csv not found"
        log_error "Make sure Stage 3 (Migration) completed successfully and published repos_with_status.csv"
        echo "##[error]repos_with_status.csv not found - Stage 3 migration may have failed"
        exit 1
    fi
    log_success "repos_with_status.csv found"
    
    # Check if any repos succeeded migration
    local success_count
    success_count=$(tail -n +2 "repos_with_status.csv" | grep -c ",Success$" || true)
    if [ "$success_count" -eq 0 ]; then
        log_error "No successfully migrated repositories found"
        log_error "All repositories failed migration. Cannot proceed with disabling."
        echo "##[error]No successfully migrated repositories - all migrations failed"
        exit 1
    fi
    log_success "Found $success_count successfully migrated repositories"
    
    # Check for required environment variables
    if [ -z "${ADO_PAT:-}" ]; then
        log_error "ADO_PAT environment variable is not set"
        echo "##[error]ADO_PAT environment variable is not set"
        exit 1
    fi
    log_success "ADO_PAT is set"
    
    if [ -z "${GH_PAT:-}" ]; then
        log_error "GH_PAT environment variable is not set"
        echo "##[error]GH_PAT environment variable is not set"
        exit 1
    fi
    log_success "GH_PAT is set"
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "gh CLI is not installed"
        exit 1
    fi
    log_success "gh CLI is installed: $(gh --version | head -n 1)"
    
    # Validate CSV headers
    if ! head -n 1 repos_with_status.csv | grep -q "org.*teamproject.*repo.*MigrationStatus"; then
        log_error "repos_with_status.csv missing required columns: org, teamproject, repo, MigrationStatus"
        exit 1
    fi
    log_success "All required columns present in repos_with_status.csv"
}

################################################################################
# Disable ADO Repository
################################################################################

disable_ado_repository() {
    local ado_org="$1"
    local ado_project="$2"
    local ado_repo="$3"
    
    log_info "Disabling ADO repository: ${ado_org}/${ado_project}/${ado_repo}"
    
    # Set environment variables for gh CLI
    export GH_TOKEN="${GH_PAT}"
    export ADO_PAT="${ADO_PAT}"
    
    # Execute gh ado2gh disable-ado-repo command
    if gh ado2gh disable-ado-repo \
        --ado-org "${ado_org}" \
        --ado-team-project "${ado_project}" \
        --ado-repo "${ado_repo}" \
        >> "$LOG_FILE" 2>&1; then
        
        log_success "Successfully disabled ADO repository: ${ado_org}/${ado_project}/${ado_repo}"
        return 0
    else
        log_error "Failed to disable ADO repository: ${ado_org}/${ado_project}/${ado_repo}"
        return 1
    fi
}

################################################################################
# Main Processing Logic
################################################################################

process_repositories() {
    log_section "PROCESSING REPOSITORIES FROM repos_with_status.csv"
    
    local line_number=0
    
    while IFS=',' read -r ado_org ado_team_project ado_repo github_org github_repo gh_repo_visibility migration_status; do
        : $((line_number++))
        
        # Skip header row
        if [ $line_number -eq 1 ]; then
            continue
        fi
        
        # Skip empty lines or lines with missing required fields
        if [ -z "$ado_org" ] || [ -z "$ado_team_project" ] || [ -z "$ado_repo" ]; then
            continue
        fi
        
        # Skip repositories that failed migration
        if [ "$migration_status" != "Success" ]; then
            log_warning "⏭️  Skipping $ado_repo (Migration Status: $migration_status)"
            continue
        fi
        
        TOTAL_REPOS=$((TOTAL_REPOS + 1))
        
        log_section "Repository $TOTAL_REPOS: ${ado_org}/${ado_team_project}/${ado_repo}"
        log_info "ADO Org: ${ado_org}"
        log_info "ADO Project: ${ado_team_project}"
        log_info "ADO Repo: ${ado_repo}"
        
        # Execute disable repository
        if disable_ado_repository "$ado_org" "$ado_team_project" "$ado_repo"; then
            SUCCESSFUL_DISABLES=$((SUCCESSFUL_DISABLES + 1))
        else
            FAILED_DISABLES=$((FAILED_DISABLES + 1))
        fi
        
        echo "" | tee -a "$LOG_FILE"
        
    done < repos_with_status.csv
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    log_section "DISABLE ADO REPOSITORIES SUMMARY"
    
    echo "" | tee -a "$LOG_FILE"
    echo "Total Repositories Processed:    ${TOTAL_REPOS}" | tee -a "$LOG_FILE"
    echo "Successfully Disabled:           ${SUCCESSFUL_DISABLES}" | tee -a "$LOG_FILE"
    echo "Failed to Disable:               ${FAILED_DISABLES}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Log file: ${LOG_FILE}" | tee -a "$LOG_FILE"
    echo "==========================================================================" | tee -a "$LOG_FILE"
    
    if [ $FAILED_DISABLES -gt 0 ]; then
        log_warning "Some repositories failed to disable. Please review the log file for details."
        echo "##[warning]Repository disable completed with $FAILED_DISABLES failures"
        echo "##vso[task.logissue type=warning]Disable repos completed: $SUCCESSFUL_DISABLES succeeded, $FAILED_DISABLES failed"
    elif [ $TOTAL_REPOS -eq 0 ]; then
        log_warning "No repositories were processed."
        echo "##[warning]No repositories were processed"
        echo "##vso[task.logissue type=warning]Disable ADO repos: No repositories found to process"
    else
        log_success "All ADO repositories disabled successfully!"
        echo "##vso[task.logissue type=warning]All $SUCCESSFUL_DISABLES ADO repositories disabled successfully"
    fi
    
    # Always exit 0 to allow pipeline to complete
    exit 0
}

################################################################################
# Main Execution
################################################################################

main() {
    log_section "DISABLE ADO REPOSITORIES"
    log_info "Script started at: $(date)"
    log_info "Log file: ${LOG_FILE}"
    
    log_warning "⚠️  WARNING: This script will DISABLE repositories in Azure DevOps!"
    log_warning "⚠️  Ensure all migrations have been validated before proceeding."
    
    validate_prerequisites
    process_repositories
    print_summary
    
    log_info "Script completed at: $(date)"
}

# Execute main function
main
