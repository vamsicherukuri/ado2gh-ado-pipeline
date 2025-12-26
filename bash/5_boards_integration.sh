#!/usr/bin/env bash

################################################################################
# Azure Boards Integration Script - ADO to GitHub Enterprise (GHE)
# 
# This script integrates Azure Boards with GitHub repositories that have been
# migrated to GitHub Enterprise.
#
# Prerequisites:
#   - repos.csv with required columns (org, teamproject, github_org, github_repo)
#   - ADO_PAT environment variable (Azure DevOps PAT with Boards scopes)
#   - GH_PAT environment variable (GitHub Personal Access Token)
#   - gh CLI installed with ado2gh extension
#
# Usage:
#   ./5_boards_integration.sh
################################################################################

set -euo pipefail

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters for summary
TOTAL_REPOS=0
SUCCESSFUL_INTEGRATIONS=0
FAILED_INTEGRATIONS=0

# Arrays to track successful and failed integrations
INTEGRATED=()
INTEGRATION_FAILED=()

# Log file
LOG_FILE="azure-boards-integration-$(date +%Y%m%d-%H%M%S).log"

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
    echo -e "${YELLOW}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
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
    
    # Check if repos.csv exists
    if [ ! -f "bash/repos.csv" ]; then
        log_error "repos.csv not found at bash/repos.csv"
        echo "##[error]repos.csv not found at bash/repos.csv"
        exit 1
    fi
    log_success "repos.csv found"
    
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
    if ! head -n 1 bash/repos.csv | grep -q "org.*teamproject.*github_org.*github_repo"; then
        log_error "repos.csv missing required columns: org, teamproject, github_org, github_repo"
        exit 1
    fi
    log_success "All required columns present in repos.csv"
}

################################################################################
# Azure Boards Integration
################################################################################

integrate_azure_boards() {
    local ado_org="$1"
    local ado_project="$2"
    local github_org="$3"
    local github_repo="$4"
    
    log_info "Integrating Azure Boards for ${github_org}/${github_repo}"
    
    # Set environment variables for gh CLI
    export GH_TOKEN="${GH_PAT}"
    export ADO_TOKEN="${ADO_PAT}"
    
    # Execute gh ado2gh integrate-boards command
    if gh ado2gh integrate-boards \
        --github-org "${github_org}" \
        --github-repo "${github_repo}" \
        --ado-org "${ado_org}" \
        --ado-team-project "${ado_project}" \
        >> "$LOG_FILE" 2>&1; then
        
        log_success "Azure Boards integration completed for ${github_org}/${github_repo}"
        return 0
    else
        log_error "Azure Boards integration failed for ${github_org}/${github_repo}"
        return 1
    fi
}

################################################################################
# Main Processing Logic
################################################################################

process_repositories() {
    log_section "PROCESSING REPOSITORIES FROM repos.csv"
    
    local line_number=0
    local current_line=""
    
    while IFS=',' read -r ado_org ado_team_project ado_repo github_org github_repo gh_repo_visibility; do
        : $((line_number++))
        
        # Skip header row
        if [ $line_number -eq 1 ]; then
            continue
        fi
        
        # Skip empty lines or lines with missing required fields
        if [ -z "$ado_org" ] || [ -z "$ado_team_project" ] || [ -z "$github_org" ] || [ -z "$github_repo" ]; then
            continue
        fi
        
        # Store current line for tracking
        current_line="$ado_org,$ado_team_project,$ado_repo,$github_org,$github_repo,$gh_repo_visibility"
        
        TOTAL_REPOS=$((TOTAL_REPOS + 1))
        
        log_section "Repository $TOTAL_REPOS: ${github_org}/${github_repo}"
        log_info "ADO Org: ${ado_org}"
        log_info "ADO Project: ${ado_team_project}"
        log_info "GitHub Org: ${github_org}"
        log_info "GitHub Repo: ${github_repo}"
        
        # Execute Azure Boards integration
        if integrate_azure_boards "$ado_org" "$ado_team_project" "$github_org" "$github_repo"; then
            SUCCESSFUL_INTEGRATIONS=$((SUCCESSFUL_INTEGRATIONS + 1))
            INTEGRATED+=("$current_line")
        else
            FAILED_INTEGRATIONS=$((FAILED_INTEGRATIONS + 1))
            INTEGRATION_FAILED+=("$current_line")
        fi
        
        echo "" | tee -a "$LOG_FILE"
        
    done < bash/repos.csv
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    log_section "AZURE BOARDS INTEGRATION SUMMARY"
    
    echo "" | tee -a "$LOG_FILE"
    echo "Total Repositories Processed:    ${TOTAL_REPOS}" | tee -a "$LOG_FILE"
    echo "Successful Integrations:         ${SUCCESSFUL_INTEGRATIONS}" | tee -a "$LOG_FILE"
    echo "Failed Integrations:             ${FAILED_INTEGRATIONS}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Log file: ${LOG_FILE}" | tee -a "$LOG_FILE"
    echo "==========================================================================" | tee -a "$LOG_FILE"
    
    if [ $FAILED_INTEGRATIONS -gt 0 ]; then
        log_warning "Some integrations failed. Please review the log file for details."
        echo "##[warning]Azure Boards integration completed with $FAILED_INTEGRATIONS failures"
        echo "##vso[task.logissue type=warning]Boards integration partial success: $FAILED_INTEGRATIONS of $TOTAL_REPOS repositories failed"
        
        # Only fail if ALL integrations failed
        if [ $SUCCESSFUL_INTEGRATIONS -eq 0 ]; then
            echo "##[error]All Azure Boards integrations failed"
            echo "##vso[task.complete result=Failed;]Azure Boards integration - all failed"
            exit 1
        fi
        
        echo "##vso[task.logissue type=warning]Proceeding with ${SUCCESSFUL_INTEGRATIONS} successful integrations"
    elif [ $TOTAL_REPOS -eq 0 ]; then
        log_warning "No repositories were processed."
        echo "##[warning]No repositories were processed"
        echo "##vso[task.logissue type=warning]Azure Boards integration: No repositories found to process"
        exit 1
    else
        log_success "Azure Boards integration completed successfully!"
        echo "##vso[task.logissue type=warning]All $SUCCESSFUL_INTEGRATIONS repositories integrated successfully with Azure Boards"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    log_section "AZURE BOARDS INTEGRATION - ADO TO GHE"
    log_info "Script started at: $(date)"
    log_info "Log file: ${LOG_FILE}"
    
    validate_prerequisites
    process_repositories
    print_summary
    
    log_info "Script completed at: $(date)"
}

# Execute main function
main
