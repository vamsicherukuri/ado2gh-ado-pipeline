#!/usr/bin/env bash
################################################################################
# Mannequin Management Script
# Usage: 
#   ./7_mannequin_manager.sh generate <github-org>
#   ./7_mannequin_manager.sh reclaim <github-org>
################################################################################

set -euo pipefail

OPERATION="${1:-}"
GITHUB_ORG="${2:-}"

if [ -z "$OPERATION" ] || [ -z "$GITHUB_ORG" ]; then
    echo "Usage: $0 {generate|reclaim} <github-org>"
    exit 1
fi

export GH_TOKEN="${GH_PAT}"

if [ "$OPERATION" == "generate" ]; then
    echo "Generating mannequins CSV for: $GITHUB_ORG"
    gh ado2gh generate-mannequin-csv --github-org "$GITHUB_ORG" --output mannequins.csv
    echo ""
    echo "✅ Generated mannequins.csv"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Download mannequins.csv from artifacts"
    echo "2. Edit 'target' column with GitHub usernames"
    echo "3. Commit updated mannequins.csv to bash/ folder"
    echo "4. Resume pipeline for Stage 7B"

elif [ "$OPERATION" == "reclaim" ]; then
    echo "Reclaiming mannequins for: $GITHUB_ORG"
    gh ado2gh reclaim-mannequin --github-org "$GITHUB_ORG" --csv bash/mannequins.csv
    echo ""
    echo "✅ Successfully reclaimed mannequins"

else
    echo "ERROR: Invalid operation '$OPERATION'"
    echo "Usage: $0 {generate|reclaim} <github-org>"
    exit 1
fi

exit 0
