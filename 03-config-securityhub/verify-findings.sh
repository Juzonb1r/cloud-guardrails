usr/bin/env bash
set -euo pipefail
aws securityhub get-findings --max-results 10 | jq '.Findings | length'
