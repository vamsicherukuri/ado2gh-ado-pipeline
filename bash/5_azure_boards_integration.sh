#!/usr/bin/env bash

################################################################################
# Azure Boards Integration Script - ADO to GitHub Enterprise (GHE)
# 
# This script integrates Azure Boards with GitHub repositories that have been
# migrated to GitHub Enterprise. It validates GitHub connections and executes
# the gh ado2gh integrate-boards command for each repository.
#
# Prerequisites:
#   - repos.csv with required columns (org, teamproject, github_org, github_repo)
#   - ADO_PAT environment variable (Azure DevOps PAT with Boards-only scopes)
#     Required scopes: Code (Read), Work Items (Read, Write), Project and Team (Read)
#     IMPORTANT: This should be a SEPARATE token from migration ADO_PAT
#   - GH_PAT environment variable (GitHub Personal Access Token)
#   - gh CLI installed with ado2gh extension
#
# Usage:
#   ./5_azure_boards_integration.sh
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
VALIDATED_CONNECTIONS=0
SKIPPED_NO_CONNECTION=0
SUCCESSFUL_INTEGRATIONS=0
FAILED_INTEGRATIONS=0

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
        log_info "This PAT requires: Code (Read), Work Items (Read, Write), Project and Team (Read)"
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
    
    # Note: gh ado2gh extension installation is handled by the pipeline
    # No need to validate here as it's a pipeline prerequisite
    
    # Validate CSV headers
    HEADER=$(head -n 1 bash/repos.csv)
    REQUIRED_COLUMNS=("org" "teamproject" "github_org" "github_repo")
    
    for col in "${REQUIRED_COLUMNS[@]}"; do
        if ! echo "$HEADER" | grep -q "$col"; then
            log_error "Missing required column in repos.csv: $col"
            exit 1
        fi
    done
    log_success "All required columns present in repos.csv"
}

################################################################################
# GitHub Connection Validation
################################################################################

validate_github_connection() {
    local ado_org="$1"
    local ado_project="$2"
    local github_org="$3"
    local github_repo="$4"
    
    log_info "Validating GitHub connection for ${github_org}/${github_repo}"
    
    # Construct API URL
    local api_url="https://dev.azure.com/${ado_org}/${ado_project}/_apis/serviceendpoint/endpoints?api-version=7.1-preview.1"
    
    # Call Azure DevOps REST API
    local response
    response=$(curl -s -u ":${ADO_PAT}" \
        -H "Content-Type: application/json" \
        "${api_url}")
    
    # Check if response contains error
    if echo "$response" | grep -q '"message"'; then
        log_error "API Error: $(echo "$response" | jq -r '.message' 2>/dev/null || echo "$response")"
        return 1
    fi
    
    # Check if any GitHub service connection exists
    local connection_count
    connection_count=$(echo "$response" | jq -r '[.value[] | select(.type == "github" or .type == "githubenterprise")] | length' 2>/dev/null || echo "0")
    
    if [ "$connection_count" -eq 0 ]; then
        log_warning "No GitHub connections found in project ${ado_project}"
        return 1
    fi
    
    # Check for specific GitHub org/repo connection (optional - depends on service endpoint naming)
    log_success "Found ${connection_count} GitHub service connection(s) in project ${ado_project}"
    
    # Log connection details
    echo "$response" | jq -r '.value[] | select(.type == "github" or .type == "githubenterprise") | "  - Connection: \(.name) | Type: \(.type)"' 2>/dev/null >> "$LOG_FILE" || true
    
    return 0
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
    local integration_log="integration-${github_org}-${github_repo}-$(date +%Y%m%d-%H%M%S).log"
    
    if gh ado2gh integrate-boards \
        --github-org "${github_org}" \
        --github-repo "${github_repo}" \
        --ado-org "${ado_org}" \
        --ado-team-project "${ado_project}" \
        2>&1 | tee "${integration_log}"; then
        
        log_success "Azure Boards integration completed for ${github_org}/${github_repo}"
        cat "${integration_log}" >> "$LOG_FILE"
        return 0
    else
        log_error "Azure Boards integration failed for ${github_org}/${github_repo}"
        cat "${integration_log}" >> "$LOG_FILE"
        return 1
    fi
}

################################################################################
# Main Processing Logic
################################################################################

process_repositories() {
    log_section "PROCESSING REPOSITORIES FROM repos.csv"
    
    # Read CSV file (skip header)
    local line_number=0
    
    while IFS= read -r line; do
        : $((line_number++))
        
        # Skip header row
        if [ $line_number -eq 1 ]; then
            continue
        fi
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Extract only the fields we need (columns 1, 2, 11, 12)
        # First 2 columns are clean
        ado_org=$(echo "$line" | cut -d',' -f1)
        ado_team_project=$(echo "$line" | cut -d',' -f2)
        
        # Last 3 columns are clean - extract from end to avoid quoted field issues
        github_org=$(echo "$line" | rev | cut -d',' -f3 | rev)
        github_repo=$(echo "$line" | rev | cut -d',' -f2 | rev)
        
        # Skip if required fields are empty
        if [ -z "$ado_org" ] || [ -z "$ado_team_project" ] || [ -z "$github_org" ] || [ -z "$github_repo" ]; then
            continue
        fi
        
        TOTAL_REPOS=$((TOTAL_REPOS + 1))
        
        log_section "Repository $TOTAL_REPOS: ${github_org}/${github_repo}"
        log_info "ADO Org: ${ado_org}"
        log_info "ADO Project: ${ado_team_project}"
        log_info "GitHub Org: ${github_org}"
        log_info "GitHub Repo: ${github_repo}"
        
        # Validate GitHub connection
        if validate_github_connection "$ado_org" "$ado_team_project" "$github_org" "$github_repo"; then
            VALIDATED_CONNECTIONS=$((VALIDATED_CONNECTIONS + 1))
            
            # Attempt Azure Boards integration
            if integrate_azure_boards "$ado_org" "$ado_team_project" "$github_org" "$github_repo"; then
                SUCCESSFUL_INTEGRATIONS=$((SUCCESSFUL_INTEGRATIONS + 1))
            else
                FAILED_INTEGRATIONS=$((FAILED_INTEGRATIONS + 1))
            fi
        else
            log_warning "Skipping Azure Boards integration - no valid GitHub connection found"
            SKIPPED_NO_CONNECTION=$((SKIPPED_NO_CONNECTION + 1))
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
    echo "Validated GitHub Connections:    ${VALIDATED_CONNECTIONS}" | tee -a "$LOG_FILE"
    echo "Skipped (No Connection):         ${SKIPPED_NO_CONNECTION}" | tee -a "$LOG_FILE"
    echo "Successful Integrations:         ${SUCCESSFUL_INTEGRATIONS}" | tee -a "$LOG_FILE"
    echo "Failed Integrations:             ${FAILED_INTEGRATIONS}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Log file: ${LOG_FILE}" | tee -a "$LOG_FILE"
    echo "==========================================================================" | tee -a "$LOG_FILE"
    
    if [ $FAILED_INTEGRATIONS -gt 0 ]; then
        log_warning "Some integrations failed. Please review the log file for details."
        echo "##[error]Azure Boards integration failed for $FAILED_INTEGRATIONS repositories"
        echo "##vso[task.logissue type=error]Boards integration failed: $FAILED_INTEGRATIONS of $TOTAL_REPOS repositories failed"
        echo "##vso[task.complete result=Failed;]Azure Boards integration completed with failures"
        exit 1
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
