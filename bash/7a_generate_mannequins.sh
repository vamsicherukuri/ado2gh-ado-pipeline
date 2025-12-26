#!/usr/bin/env bash

################################################################################
# Generate Mannequin CSV Script
# 
# This script generates mannequin CSV files for each unique GitHub organization
# found in repos.csv. These CSVs will be used to map ADO users to GitHub users.
#
# Prerequisites:
#   - repos.csv with required columns (github_org)
#   - GH_PAT environment variable (GitHub Personal Access Token)
#   - gh CLI installed with ado2gh extension
#
# Usage:
#   ./7a_generate_mannequins.sh
#
# Output:
#   - mannequins-{github_org}.csv for each unique GitHub org
################################################################################

set -euo pipefail

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters for summary
TOTAL_ORGS=0
SUCCESSFUL_GENERATIONS=0
FAILED_GENERATIONS=0

# Log file
LOG_FILE="generate-mannequins-$(date +%Y%m%d-%H%M%S).log"

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
    echo -e "${CYAN}$1${NC}" | tee -a "$LOG_FILE"
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
    if ! head -n 1 bash/repos.csv | grep -q "github_org"; then
        log_error "repos.csv missing required column: github_org"
        exit 1
    fi
    log_success "Required column present in repos.csv"
}

################################################################################
# Extract Unique GitHub Organizations
################################################################################

get_unique_github_orgs() {
    log_section "EXTRACTING UNIQUE GITHUB ORGANIZATIONS"
    
    local orgs=()
    local line_number=0
    
    while IFS=',' read -r org teamproject repo github_org github_repo gh_repo_visibility; do
        : $((line_number++))
        
        # Skip header row
        if [ $line_number -eq 1 ]; then
            continue
        fi
        
        # Skip empty lines
        if [ -z "$github_org" ]; then
            continue
        fi
        
        # Remove quotes if present
        github_org="${github_org//\"/}"
        
        # Add to array if not already present
        if [[ ! " ${orgs[@]} " =~ " ${github_org} " ]]; then
            orgs+=("$github_org")
            log_info "Found GitHub org: ${github_org}"
        fi
        
    done < bash/repos.csv
    
    echo "${orgs[@]}"
}

################################################################################
# Generate Mannequin CSV
################################################################################

generate_mannequin_csv() {
    local github_org="$1"
    local output_file="mannequins-${github_org}.csv"
    
    log_info "Generating mannequin CSV for GitHub org: ${github_org}"
    log_info "Output file: ${output_file}"
    
    # Set environment variables for gh CLI
    export GH_TOKEN="${GH_PAT}"
    
    # Execute gh ado2gh generate-mannequin-csv command
    if gh ado2gh generate-mannequin-csv \
        --github-org "${github_org}" \
        --output "${output_file}" \
        >> "$LOG_FILE" 2>&1; then
        
        if [ -f "${output_file}" ]; then
            local mannequin_count=$(( $(wc -l < "${output_file}") - 1 ))
            log_success "Generated mannequin CSV for ${github_org}: ${mannequin_count} mannequins found"
            log_info "File: ${output_file}"
            return 0
        else
            log_error "Mannequin CSV file not created for ${github_org}"
            return 1
        fi
    else
        log_error "Failed to generate mannequin CSV for ${github_org}"
        return 1
    fi
}

################################################################################
# Main Processing Logic
################################################################################

process_github_organizations() {
    log_section "GENERATING MANNEQUIN CSV FILES"
    
    # Get unique GitHub organizations
    local -a github_orgs
    read -ra github_orgs <<< "$(get_unique_github_orgs)"
    
    TOTAL_ORGS=${#github_orgs[@]}
    
    if [ $TOTAL_ORGS -eq 0 ]; then
        log_warning "No GitHub organizations found in repos.csv"
        return
    fi
    
    log_info "Processing ${TOTAL_ORGS} unique GitHub organization(s)"
    echo "" | tee -a "$LOG_FILE"
    
    for github_org in "${github_orgs[@]}"; do
        log_section "GitHub Organization: ${github_org}"
        
        if generate_mannequin_csv "$github_org"; then
            SUCCESSFUL_GENERATIONS=$((SUCCESSFUL_GENERATIONS + 1))
        else
            FAILED_GENERATIONS=$((FAILED_GENERATIONS + 1))
        fi
        
        echo "" | tee -a "$LOG_FILE"
    done
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    log_section "MANNEQUIN CSV GENERATION SUMMARY"
    
    echo "" | tee -a "$LOG_FILE"
    echo "Total GitHub Organizations:      ${TOTAL_ORGS}" | tee -a "$LOG_FILE"
    echo "Successfully Generated:          ${SUCCESSFUL_GENERATIONS}" | tee -a "$LOG_FILE"
    echo "Failed to Generate:              ${FAILED_GENERATIONS}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Log file: ${LOG_FILE}" | tee -a "$LOG_FILE"
    echo "==========================================================================" | tee -a "$LOG_FILE"
    
    if [ $SUCCESSFUL_GENERATIONS -gt 0 ]; then
        echo "" | tee -a "$LOG_FILE"
        log_info "📋 NEXT STEPS:"
        log_info "1. Download the generated mannequins-*.csv file(s) from pipeline artifacts"
        log_info "2. Open each CSV file and fill in the 'target' column with actual GitHub usernames"
        log_info "3. Commit the updated CSV file(s) back to the repository in the 'bash/' folder"
        log_info "4. Resume the pipeline to proceed with mannequin reclamation"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    if [ $FAILED_GENERATIONS -gt 0 ]; then
        log_warning "Some CSV generations failed. Please review the log file for details."
        echo "##[warning]Mannequin CSV generation completed with $FAILED_GENERATIONS failures"
        echo "##vso[task.logissue type=warning]Generate mannequins: $SUCCESSFUL_GENERATIONS succeeded, $FAILED_GENERATIONS failed"
    elif [ $TOTAL_ORGS -eq 0 ]; then
        log_warning "No GitHub organizations were processed."
        echo "##[warning]No GitHub organizations were processed"
        echo "##vso[task.logissue type=warning]Generate mannequins: No organizations found to process"
    else
        log_success "All mannequin CSV files generated successfully!"
        echo "##vso[task.logissue type=warning]All $SUCCESSFUL_GENERATIONS mannequin CSV files generated successfully"
    fi
    
    # Always exit 0 to allow pipeline to continue
    exit 0
}

################################################################################
# Main Execution
################################################################################

main() {
    log_section "GENERATE MANNEQUIN CSV FILES"
    log_info "Script started at: $(date)"
    log_info "Log file: ${LOG_FILE}"
    
    validate_prerequisites
    process_github_organizations
    print_summary
    
    log_info "Script completed at: $(date)"
}

# Execute main function
main
