#!/usr/bin/env bash

################################################################################
# Azure Boards Integration Script - ADO to GitHub Enterprise (GHE)
# 
# This script integrates Azure Boards with GitHub repositories that have been
# migrated to GitHub Enterprise using the gh ado2gh integrate-boards command.
#
# Prerequisites:
#   - repos.csv with required columns (org, teamproject, github_org, github_repo)
#   - ADO_PAT environment variable (Azure DevOps PAT with Work Items scope)
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
        2>&1 | tee -a "$LOG_FILE"; then
        
        log_success "Azure Boards integration completed for ${github_org}/${github_repo}"
        return 0
    else
        log_error "Azure Boards integration failed for ${github_org}/${github_repo}"
        return 1
    fi
}

################################################################################
# CSV Parsing Helper
################################################################################

# Robust CSV line parser (quoted fields, escaped quotes)
parse_csv_line() {
  local line="$1"
  local -a fields=()
  local field="" in_quotes=false i char next
  for ((i=0; i<${#line}; i++)); do
    char="${line:$i:1}"
    next="${line:$((i+1)):1}"
    if [[ "${char}" == '"' ]]; then
      if [[ "${in_quotes}" == true ]]; then
        if [[ "${next}" == '"' ]]; then
          field+='"'; : $((i++))
        else
          in_quotes=false
        fi
      else
        in_quotes=true
      fi
    elif [[ "${char}" == ',' && "${in_quotes}" == false ]]; then
      fields+=("${field}")
      field=""
    else
      field+="${char}"
    fi
  done
  fields+=("${field}")
  printf '%s\n' "${fields[@]}"
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
        
        # Parse CSV line properly handling quoted fields
        # CSV has 6 columns: org,teamproject,repo,github_org,github_repo,gh_repo_visibility
        mapfile -t fields < <(parse_csv_line "$line")
        
        ado_org="${fields[0]}"
        ado_team_project="${fields[1]}"
        github_org="${fields[3]}"
        github_repo="${fields[4]}"
        
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
        
        # Integrate Azure Boards
        if integrate_azure_boards "$ado_org" "$ado_team_project" "$github_org" "$github_repo"; then
            SUCCESSFUL_INTEGRATIONS=$((SUCCESSFUL_INTEGRATIONS + 1))
        else
            FAILED_INTEGRATIONS=$((FAILED_INTEGRATIONS + 1))
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
        log_error "Some integrations failed. Please review the log file for details."
        echo "##[error]Azure Boards integration failed for $FAILED_INTEGRATIONS repositories"
        echo "##vso[task.complete result=Failed;]Azure Boards integration completed with failures"
        exit 1
    elif [ $TOTAL_REPOS -eq 0 ]; then
        log_error "No repositories were processed."
        echo "##[error]No repositories were processed"
        exit 1
    else
        log_success "Azure Boards integration completed successfully for all $SUCCESSFUL_INTEGRATIONS repositories!"
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
