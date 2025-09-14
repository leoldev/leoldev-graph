#!/usr/bin/env bash
# Weekly reset of the contribution-art repo, driven by launchd
# (~/Library/LaunchAgents/com.ldpleo.graph-purge.plist, Mondays 13:30
# local = 03:30 UTC — deliberately 47 min BEFORE the cloud read-back at
# 04:17 UTC, so the fresh repo already carries the verify-only workflow
# when the cron fires).
#
# Why a repo reset at all: GitHub RETAINS contribution events across
# force-pushes (observed: old designs stayed painted for hours), so the
# only reliable way to re-pin the art to the sliding 53-week window is
# delete + recreate + re-push.  A GitHub Actions workflow cannot do this
# to its own repository (deletion kills the run; GITHUB_TOKEN has no
# delete_repo scope) — hence this local job.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
cd "$(dirname "$0")"

{
  echo "=== weekly purge $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

  # 1. read back LAST week's fully-indexed render before rewriting it
  #    (the cloud cron can't do this any more: it runs after the reset).
  python3 encode.py --verify || echo "pre-purge verify reported issues (continuing)"

  # 2. reset. One retry: if a run died after delete but before the
  #    push, the repo is gone — a second full run cleanly re-creates it
  #    (purge.sh is idempotent).
  ./purge.sh || { echo "first attempt failed, retrying in 15s"; sleep 15; ./purge.sh; }

  # 3. confirm the recreated repo's workflow state
  sleep 20
  gh api repos/leoldev/leoldev-graph/actions/workflows \
    --jq '.workflows[] | "workflow \(.path) state=\(.state)"'
} >> "$(dirname "$0")/weekly-purge.log" 2>&1
