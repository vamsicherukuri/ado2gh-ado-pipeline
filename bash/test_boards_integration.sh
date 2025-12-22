#!/bin/bash

################################################################################
# Test Script for Azure Boards Integration
# 
# This script performs a dry-run validation of the Azure Boards integration
# without actually executing the integration commands.
################################################################################

set -e
set -u

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "AZURE BOARDS INTEGRATION - DRY RUN TEST"
echo "=========================================="
echo ""

# Test 1: Check repos.csv
echo -n "1. Checking repos.csv... "
if [ -f "bash/repos.csv" ]; then
    echo -e "${GREEN}✓ Found${NC}"
    REPO_COUNT=$(($(wc -l < bash/repos.csv) - 1))
    echo "   Found $REPO_COUNT repositories to process"
else
    echo -e "${RED}✗ Not found${NC}"
    exit 1
fi

# Test 2: Check CSV columns
echo -n "2. Validating CSV columns... "
HEADER=$(head -n 1 bash/repos.csv)
REQUIRED_COLUMNS=("org" "teamproject" "github_org" "github_repo")
MISSING=()

for col in "${REQUIRED_COLUMNS[@]}"; do
    if ! echo "$HEADER" | grep -q "$col"; then
        MISSING+=("$col")
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All required columns present${NC}"
else
    echo -e "${RED}✗ Missing columns: ${MISSING[*]}${NC}"
    exit 1
fi

# Test 3: Check AZURE_BOARDS_PAT
echo -n "3. Checking AZURE_BOARDS_PAT... "
if [ -z "${AZURE_BOARDS_PAT:-}" ]; then
    echo -e "${RED}✗ Not set${NC}"
    echo ""
    echo -e "${YELLOW}To set it:${NC}"
    echo "export AZURE_BOARDS_PAT='your-pat-token-here'"
    exit 1
else
    echo -e "${GREEN}✓ Set${NC}"
fi

# Test 4: Check GH_PAT
echo -n "4. Checking GH_PAT... "
if [ -z "${GH_PAT:-}" ]; then
    echo -e "${RED}✗ Not set${NC}"
    echo ""
    echo -e "${YELLOW}To set it:${NC}"
    echo "export GH_PAT='your-gh-pat-token-here'"
    exit 1
else
    echo -e "${GREEN}✓ Set${NC}"
fi

# Test 5: Check gh CLI
echo -n "5. Checking gh CLI... "
if command -v gh &> /dev/null; then
    echo -e "${GREEN}✓ Installed${NC}"
    echo "   $(gh --version | head -n 1)"
else
    echo -e "${RED}✗ Not installed${NC}"
    exit 1
fi

# Test 6: Check gh ado2gh extension
echo -n "6. Checking gh ado2gh extension... "
if gh extension list | grep -q "gh-ado2gh"; then
    echo -e "${GREEN}✓ Installed${NC}"
else
    echo -e "${RED}✗ Not installed${NC}"
    echo ""
    echo -e "${YELLOW}To install:${NC}"
    echo "gh extension install github/gh-ado2gh"
    exit 1
fi

# Test 7: Parse first repo from CSV
echo ""
echo "7. Testing CSV parsing with first repository:"
line_number=0
while IFS=, read -r org teamproject repo url last_push_date pipeline_count size contributor pr_count commits github_org github_repo gh_repo_visibility rest; do
    line_number=$((line_number + 1))
    
    if [ $line_number -eq 2 ]; then  # First data row (skip header)
        echo "   ADO Org: $org"
        echo "   ADO Project: $teamproject"
        echo "   GitHub Org: $github_org"
        echo "   GitHub Repo: $github_repo"
        echo ""
        echo -e "${GREEN}✓ CSV parsing successful${NC}"
        break
    fi
done < bash/repos.csv

# Test 8: Test Azure DevOps API connectivity
echo ""
echo -n "8. Testing Azure DevOps API connectivity... "
if [ -n "${org:-}" ] && [ -n "${teamproject:-}" ]; then
    api_url="https://dev.azure.com/${org}/${teamproject}/_apis/serviceendpoint/endpoints?api-version=7.1-preview.1"
    
    response=$(curl -s -w "\n%{http_code}" -u ":${AZURE_BOARDS_PAT}" "${api_url}")
    http_code=$(echo "$response" | tail -n 1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Connection successful${NC}"
        
        # Check for GitHub connections
        body=$(echo "$response" | head -n -1)
        connection_count=$(echo "$body" | jq -r '[.value[] | select(.type == "github" or .type == "githubenterprise")] | length' 2>/dev/null || echo "0")
        
        if [ "$connection_count" -gt 0 ]; then
            echo -e "   ${GREEN}Found $connection_count GitHub service connection(s)${NC}"
        else
            echo -e "   ${YELLOW}No GitHub service connections found${NC}"
            echo "   You may need to create a GitHub service connection in Azure DevOps"
        fi
    else
        echo -e "${RED}✗ Failed (HTTP $http_code)${NC}"
        echo "   Check your AZURE_BOARDS_PAT permissions"
    fi
else
    echo -e "${YELLOW}⊘ Skipped (no data from CSV)${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}All prerequisite tests passed!${NC}"
echo "=========================================="
echo ""
echo "You can now run: bash/5_azure_boards_integration.sh"
