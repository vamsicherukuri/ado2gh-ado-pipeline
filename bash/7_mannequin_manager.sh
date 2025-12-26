#!/usr/bin/env bash
################################################################################
# Mannequin Management Script
# Usage: 
#   ./7_mannequin_manager.sh generate  - Generate mannequin CSVs
#   ./7_mannequin_manager.sh reclaim   - Reclaim mannequins using updated CSVs
################################################################################

set -euo pipefail

OPERATION="${1:-generate}"
CSV_FILE="bash/repos.csv"

export GH_TOKEN="${GH_PAT}"

# Extract unique GitHub organizations from repos.csv (column 4)
get_unique_orgs() {
    tail -n +2 "$CSV_FILE" | cut -d',' -f4 | tr -d '"' | sort -u | grep -v '^$'
}

if [ "$OPERATION" == "generate" ]; then
    echo "=========================================="
    echo "GENERATING MANNEQUIN CSVs"
    echo "=========================================="
    
    if [ ! -f "$CSV_FILE" ]; then
        echo "ERROR: $CSV_FILE not found"
        exit 1
    fi
    
    ORGS=($(get_unique_orgs))
    echo "Found ${#ORGS[@]} unique GitHub organization(s): ${ORGS[*]}"
    echo ""
    
    SUCCESS=0
    FAILED=0
    
    for org in "${ORGS[@]}"; do
        echo "Generating mannequins CSV for: $org"
        if gh ado2gh generate-mannequin-csv --github-org "$org" --output "mannequins-${org}.csv"; then
            COUNT=$(($(wc -l < "mannequins-${org}.csv") - 1))
            echo "✅ Generated mannequins-${org}.csv ($COUNT mannequins)"
            SUCCESS=$((SUCCESS + 1))
        else
            echo "❌ Failed to generate CSV for $org"
            FAILED=$((FAILED + 1))
        fi
        echo ""
    done
    
    echo "=========================================="
    echo "SUMMARY: $SUCCESS succeeded, $FAILED failed"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Download mannequins-*.csv from artifacts"
    echo "2. Edit 'target' column with GitHub usernames"
    echo "3. Commit updated CSVs to bash/ folder"
    echo "4. Resume pipeline for Stage 7B"
    echo "=========================================="

elif [ "$OPERATION" == "reclaim" ]; then
    echo "=========================================="
    echo "RECLAIMING MANNEQUINS"
    echo "=========================================="
    
    CSV_FILES=(bash/mannequins-*.csv)
    
    if [ ! -f "${CSV_FILES[0]}" ]; then
        echo "ERROR: No mannequin CSV files found in bash/"
        echo "Expected files: bash/mannequins-*.csv"
        exit 1
    fi
    
    echo "Found ${#CSV_FILES[@]} mannequin CSV file(s)"
    echo ""
    
    SUCCESS=0
    FAILED=0
    
    for csv_file in "${CSV_FILES[@]}"; do
        ORG=$(basename "$csv_file" .csv | sed 's/^mannequins-//')
        echo "Reclaiming mannequins for: $ORG (using $csv_file)"
        
        if gh ado2gh reclaim-mannequin --github-org "$ORG" --csv "$csv_file"; then
            echo "✅ Successfully reclaimed mannequins for $ORG"
            SUCCESS=$((SUCCESS + 1))
        else
            echo "❌ Failed to reclaim mannequins for $ORG"
            FAILED=$((FAILED + 1))
        fi
        echo ""
    done
    
    echo "=========================================="
    echo "SUMMARY: $SUCCESS succeeded, $FAILED failed"
    echo "=========================================="

else
    echo "ERROR: Invalid operation '$OPERATION'"
    echo "Usage: $0 {generate|reclaim}"
    exit 1
fi

# Always exit 0 to allow pipeline to continue
exit 0
