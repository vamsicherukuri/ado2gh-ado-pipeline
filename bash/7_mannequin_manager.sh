#!/usr/bin/env bash
set -euo pipefail

OPERATION="${1:-}"
CSV_FILE="bash/repos.csv"

if [ -z "$OPERATION" ]; then
    echo "Usage: $0 {generate|reclaim}"
    exit 1
fi

export GH_TOKEN="${GH_PAT}"

# Extract unique github_org from repos.csv (column 4)
GITHUB_ORG=$(tail -n +2 "$CSV_FILE" | cut -d',' -f4 | tr -d '"' | sort -u | head -n1)

if [ -z "$GITHUB_ORG" ]; then
    echo "ERROR: Could not find github_org in $CSV_FILE"
    exit 1
fi

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
    echo "Usage: $0 {generate|reclaim}"
    exit 1
fi

exit 0
