#!/usr/bin/env bash
set -euo pipefail

# Copyright (c) 2025 Vamsi Cherukuri, Microsoft
# 
# MIT License
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Verify GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo "ERROR: GitHub CLI (gh) not found. Please install it first."
    exit 1
fi

# ADO2GH: Rewire Pipelines
# 
# Description:
#   Rewires Azure DevOps pipelines to GitHub repositories.
#   Reads pipeline information from pipelines.csv and executes rewiring for each pipeline.
#
# Prerequisites:
#   - ADO_PAT and GH_PAT environment variables set
#   - pipelines.csv with required columns: org, teamproject, pipeline, github_org, github_repo, serviceConnection
#
# Usage:
#   ./4_rewire_pipeline.sh
#
# Workflow:
#   [Step 1] Validate PAT tokens (ADO_PAT and GH_PAT)
#   [Step 2] Validate pipelines.csv file and required columns
#   [Step 3] Validate service connection IDs (no placeholders)
#   [Step 4] Execute pipeline rewiring
#   [Step 5] Generate summary and log file

# ========================================
# CONFIGURATION
# ========================================
PIPELINES_FILE="pipelines.csv"
REQUIRED_COLUMNS=("org" "teamproject" "pipeline" "github_org" "github_repo" "serviceConnection")
PLACEHOLDER_VALUES=("your-service-connection-id" "placeholder" "TODO" "TBD" "xxx" "")

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Counters
SUCCESS_COUNT=0
FAILURE_COUNT=0
declare -a RESULTS

# ========================================
# HELPER FUNCTIONS
# ========================================

# Function to parse CSV line properly (handles quoted fields)
parse_csv_line() {
    local line="$1"
    local IFS=','
    local -a fields
    
    # Simple CSV parsing (assumes no commas within quoted fields for this use case)
    IFS=',' read -ra fields <<< "$line"
    
    # Remove quotes from fields
    for i in "${!fields[@]}"; do
        fields[$i]=$(echo "${fields[$i]}" | sed 's/^"//;s/"$//')
    done
    
    echo "${fields[@]}"
}

# ========================================
# MAIN SCRIPT
# ========================================
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}  ADO2GH: Rewire Pipelines${NC}"
echo -e "${CYAN}========================================${NC}\n"

# ========================================
# STEP 1: Validate PAT Tokens
# ========================================
echo -e "${YELLOW}[Step 1/4] Validating PAT tokens...${NC}"

if [ -z "$ADO_PAT" ]; then
    echo -e "${RED}❌ ERROR: ADO_PAT environment variable is not set${NC}"
    exit 1
fi

if [ -z "$GH_PAT" ]; then
    echo -e "${RED}❌ ERROR: GH_PAT environment variable is not set${NC}"
    exit 1
fi

echo -e "${GREEN}✅ PAT tokens validated${NC}"

# ========================================
# STEP 2: Validate pipelines.csv File
# ========================================
echo -e "\n${YELLOW}[Step 2/4] Validating pipelines.csv file...${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_PATH="$SCRIPT_DIR/$PIPELINES_FILE"

# Check file exists
if [ ! -f "$CSV_PATH" ]; then
    echo -e "${RED}❌ ERROR: Pipeline file not found: $CSV_PATH${NC}"
    echo -e "${YELLOW}   Please ensure pipelines.csv exists in the current directory${NC}"
    exit 1
fi

# Load CSV and count lines
TOTAL_LINES=$(wc -l < "$CSV_PATH")
PIPELINE_COUNT=$((TOTAL_LINES - 1))  # Subtract header

if [ $PIPELINE_COUNT -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No pipelines found in CSV file${NC}"
    echo -e "${GRAY}   Nothing to process. Exiting.${NC}"
    exit 0
fi

echo -e "${GREEN}✅ File loaded: $PIPELINE_COUNT pipeline(s) found${NC}"

# ========================================
# STEP 3: Validate Required Columns
# ========================================
echo -e "\n${YELLOW}[Step 3/4] Validating CSV columns and data...${NC}"

# Read header and validate columns
IFS=',' read -ra CSV_COLUMNS <<< "$(head -n 1 "$CSV_PATH")"

# Remove quotes and whitespace from column names
for i in "${!CSV_COLUMNS[@]}"; do
    CSV_COLUMNS[$i]=$(echo "${CSV_COLUMNS[$i]}" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
done

# Check for missing columns
MISSING_COLUMNS=()
for req_col in "${REQUIRED_COLUMNS[@]}"; do
    found=false
    for csv_col in "${CSV_COLUMNS[@]}"; do
        if [ "$csv_col" = "$req_col" ]; then
            found=true
            break
        fi
    done
    if [ "$found" = "false" ]; then
        MISSING_COLUMNS+=("$req_col")
    fi
done

if [ ${#MISSING_COLUMNS[@]} -gt 0 ]; then
    echo -e "${RED}❌ ERROR: CSV is missing required columns: ${MISSING_COLUMNS[*]}${NC}"
    echo -e "${YELLOW}   Required columns: ${REQUIRED_COLUMNS[*]}${NC}"
    echo -e "${GRAY}   Found columns: ${CSV_COLUMNS[*]}${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All required columns present${NC}"

# Get column indices
declare -A COL_INDEX
for i in "${!CSV_COLUMNS[@]}"; do
    COL_INDEX["${CSV_COLUMNS[$i]}"]=$i
done

# Validate service connection IDs
echo -e "${GRAY}   Validating service connection IDs...${NC}"
INVALID_ROWS=()
ROW_NUM=1

while IFS= read -r line; do
    ROW_NUM=$((ROW_NUM + 1))
    
    # Parse CSV line
    IFS=',' read -ra fields <<< "$line"
    
    # Remove quotes
    for i in "${!fields[@]}"; do
        fields[$i]=$(echo "${fields[$i]}" | sed 's/^"//;s/"$//')
    done
    
    # Get service connection ID
    SERVICE_CONN_ID="${fields[${COL_INDEX["serviceConnection"]}]}"
    PIPELINE_NAME="${fields[${COL_INDEX["pipeline"]}]}"
    
    # Check if empty or placeholder
    if [ -z "$SERVICE_CONN_ID" ]; then
        INVALID_ROWS+=("Row $ROW_NUM: $PIPELINE_NAME - Empty service connection ID")
    else
        for placeholder in "${PLACEHOLDER_VALUES[@]}"; do
            if [ "$SERVICE_CONN_ID" == "$placeholder" ]; then
                INVALID_ROWS+=("Row $ROW_NUM: $PIPELINE_NAME - Placeholder value: '$SERVICE_CONN_ID'")
                break
            fi
        done
    fi
done < <(tail -n +2 "$CSV_PATH")

if [ ${#INVALID_ROWS[@]} -gt 0 ]; then
    echo -e "\n${RED}❌ ERROR: Invalid service connection IDs found${NC}"
    echo -e "${YELLOW}   The following rows have issues:\n${NC}"
    
    for invalid in "${INVALID_ROWS[@]}"; do
        echo -e "${YELLOW}      $invalid${NC}"
    done
    
    echo -e "\n${CYAN}   💡 How to fix:${NC}"
    echo -e "${GRAY}      1. Go to Azure DevOps → Project Settings → Service Connections${NC}"
    echo -e "${GRAY}      2. Find your GitHub service connection${NC}"
    echo -e "${GRAY}      3. Copy the connection ID (GUID format)${NC}"
    echo -e "${GRAY}      4. Update the 'serviceConnection' column in pipelines.csv${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All service connection IDs validated${NC}"

# ========================================
# STEP 4: Rewire Pipelines
# ========================================
echo -e "\n${YELLOW}[Step 4/4] Rewiring pipelines to GitHub...${NC}"

while IFS= read -r line; do
    # Parse CSV line
    IFS=',' read -ra fields <<< "$line"
    
    # Remove quotes
    for i in "${!fields[@]}"; do
        fields[$i]=$(echo "${fields[$i]}" | sed 's/^"//;s/"$//')
    done
    
    # Extract fields
    ADO_ORG="${fields[${COL_INDEX["org"]}]}"
    ADO_PROJECT="${fields[${COL_INDEX["teamproject"]}]}"
    ADO_PIPELINE="${fields[${COL_INDEX["pipeline"]}]}"
    GITHUB_ORG="${fields[${COL_INDEX["github_org"]}]}"
    GITHUB_REPO="${fields[${COL_INDEX["github_repo"]}]}"
    SERVICE_CONNECTION_ID="${fields[${COL_INDEX["serviceConnection"]}]}"
    
    echo -e "\n${CYAN}   🔄 Processing: $ADO_PIPELINE${NC}"
    echo -e "${GRAY}      ADO: $ADO_ORG/$ADO_PROJECT${NC}"
    echo -e "${GRAY}      GitHub: $GITHUB_ORG/$GITHUB_REPO${NC}"
    echo -e "${GRAY}      Service Connection: $SERVICE_CONNECTION_ID${NC}"
    
    # Execute gh ado2gh rewire-pipeline
    if gh ado2gh rewire-pipeline \
        --ado-org "$ADO_ORG" \
        --ado-team-project "$ADO_PROJECT" \
        --ado-pipeline "$ADO_PIPELINE" \
        --github-org "$GITHUB_ORG" \
        --github-repo "$GITHUB_REPO" \
        --service-connection-id "$SERVICE_CONNECTION_ID"; then
        
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo -e "${GREEN}      ✅ SUCCESS${NC}"
        RESULTS+=("✅ SUCCESS | $ADO_PROJECT/$ADO_PIPELINE → $GITHUB_ORG/$GITHUB_REPO")
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        echo -e "${RED}      ❌ FAILED${NC}"
        RESULTS+=("❌ FAILED | $ADO_PROJECT/$ADO_PIPELINE → $GITHUB_ORG/$GITHUB_REPO")
    fi
    
    sleep 1
    
done < <(tail -n +2 "$CSV_PATH")

# ========================================
# STEP 5: Generate Summary and Log
# ========================================
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}  Pipeline Rewiring Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "Total Pipelines: $PIPELINE_COUNT"
echo -e "${GREEN}Successful: $SUCCESS_COUNT${NC}"
echo -e "${RED}Failed: $FAILURE_COUNT${NC}"

echo -e "\n${CYAN}📋 Detailed Results:${NC}"
for result in "${RESULTS[@]}"; do
    echo -e "${GRAY}   $result${NC}"
done

# Generate log file
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
LOG_FILE="pipeline-rewiring-$(date "+%Y%m%d-%H%M%S").txt"

cat > "$LOG_FILE" << EOF
Pipeline Rewiring Log - $TIMESTAMP
========================================
Total Pipelines: $PIPELINE_COUNT
Successful: $SUCCESS_COUNT
Failed: $FAILURE_COUNT

Detailed Results:
$(printf '%s\n' "${RESULTS[@]}")
========================================
EOF

echo -e "\n${GRAY}📄 Log saved: $LOG_FILE${NC}"

# ========================================
# EXIT WITH APPROPRIATE STATUS
# ========================================
if [ $FAILURE_COUNT -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All pipelines rewired successfully!${NC}"
    exit 0
elif [ $SUCCESS_COUNT -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️  Partial success: $SUCCESS_COUNT succeeded, $FAILURE_COUNT failed${NC}"
    exit 0
else
    echo -e "\n${RED}❌ All pipeline rewiring attempts failed${NC}"
    exit 1
fi
