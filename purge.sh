#!/usr/bin/env bash
# Reset the contribution-art repo: delete + recreate + re-encode.
#
# This is the PRIMARY weekly mechanism (invoked by weekly-purge.sh via
# launchd): GitHub RETAINS contribution events across force-pushes, so a
# repo reset is the only reliable way to re-pin the art to the sliding
# 53-week window.  Needs `gh` with the delete_repo scope (local login
# has it: `gh auth refresh -s delete_repo`).  Idempotent: safe if a
# previous run died halfway (repo already gone / already present).
set -euo pipefail
cd "$(dirname "$0")"
REPO="${1:-leoldev/leoldev-graph}"

if gh repo view "$REPO" >/dev/null 2>&1; then
  gh repo delete "$REPO" --yes
  echo "deleted $REPO"
  sleep 5
else
  echo "$REPO already absent — skipping delete"
fi

if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "error: repo still exists after delete" >&2
  exit 1
fi

# No --add-readme: a placeholder README commit would leave a stray
# contribution event after recode.sh's force-push of chunk 1.
gh repo create "$REPO" --public \
  --description "white '@leoldev' + LinkedIn tile on an inverted gradient — generated contribution art"
echo "recreated $REPO"

# authenticated push URL (never echoed: recode.sh strips credentials when printing)
REMOTE_URL="${REMOTE_URL:-https://x-access-token:$(gh auth token)@github.com/${REPO}.git}" \
ART_NAME="${ART_NAME:-leoldev}" \
ART_EMAIL="${ART_EMAIL:-341686751+leoldev@users.noreply.github.com}" \
  ./recode.sh
echo "re-encoded $REPO — graph rebuilds within 24h"
