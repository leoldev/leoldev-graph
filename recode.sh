#!/usr/bin/env bash
# Build the art repo history (project files + backdated empty commits)
# and push it in chunks. GitHub's contribution indexer only seems to
# process ~1,000 events per push before stalling, so we advance the
# branch in PUSH_CHUNK-commit steps (default 900) with PUSH_GAP seconds
# between pushes instead of one giant force-push.
#   DRY_RUN=1 ./recode.sh             -> build locally, don't push
#   REMOTE_URL=https://... ./recode.sh -> push target (or set origin first)
#   ART_EMAIL=...                     -> must be your noreply address
#   PUSH_CHUNK=900 PUSH_GAP=120       -> chunked-push tuning
set -euo pipefail
cd "$(dirname "$0")"

ART_NAME="${ART_NAME:-leoldev}"
ART_EMAIL="${ART_EMAIL:-341686751+leoldev@users.noreply.github.com}"
DRY="${DRY_RUN:-0}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

python3 encode.py --plan "$work/plan.tsv"

git init -q -b main "$work/repo"
git -C "$work/repo" config user.name  "$ART_NAME"
git -C "$work/repo" config user.email "$ART_EMAIL"

# Project files + README, dated ~400 days ago so they sit OUTSIDE the
# 12-month graph window (zero contribution impact).
mkdir -p "$work/repo/.github/workflows"
cp encode.py recode.sh purge.sh weekly-purge.sh daily-topup.sh README.md "$work/repo/"
cp .github/workflows/recode.yml "$work/repo/.github/workflows/"
old="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(days=400)).strftime("%Y-%m-%dT12:00:00+0000"))')"
git -C "$work/repo" add -A
GIT_AUTHOR_DATE="$old" GIT_COMMITTER_DATE="$old" \
  git -C "$work/repo" commit -q -m "project files"

# GitHub's live count per day AFTER the purge wiped this repo's events.
# A day may still hold REAL commits from your other repos; seed only the
# deficit so the day lands exactly on its design target instead of
# overshooting (which would raise the graph's max and dim the art).
python3 encode.py --existing "$work/live.tsv" >/dev/null

n=0
while IFS=$'\t' read -r d count; do
  have="$(awk -F'\t' -v k="$d" '$1==k{print $2}' "$work/live.tsv")"
  need=$(( count - ${have:-0} ))
  if [ "$need" -le 0 ]; then continue; fi
  for ((i = 0; i < need; i++)); do
    GIT_AUTHOR_DATE="${d}T12:00:00+0000" GIT_COMMITTER_DATE="${d}T12:00:00+0000" \
      git -C "$work/repo" commit -q --allow-empty -m "art ${d}"
    n=$((n + 1))
  done
done < "$work/plan.tsv"

total="$(git -C "$work/repo" rev-list --count HEAD)"
echo "built: $total commits ($n art + 1 project files) in $work/repo"
git -C "$work/repo" log --format='%ad %s' --date=short | tail -3

if [ "$DRY" = 1 ]; then
  echo "DRY_RUN=1 -> not pushing"
  exit 0
fi

if [ -n "${REMOTE_URL:-}" ]; then
  git -C "$work/repo" remote add origin "$REMOTE_URL"
fi
if ! git -C "$work/repo" remote get-url origin >/dev/null 2>&1; then
  echo "error: no remote — set REMOTE_URL" >&2
  exit 1
fi

remote="$(git -C "$work/repo" remote get-url origin)"
safe="$(printf '%s' "$remote" | sed -E 's#//[^@]*@#//@#')"

# Advance the branch in chunks: each push's delta is <= PUSH_COMMIT_CAP
# new commits so GitHub's indexer (one ~1,000-event batch per push)
# ingests it fully before the next chunk arrives. First push creates the
# branch; later pushes are fast-forwards — no force needed.
CHUNK="${PUSH_CHUNK:-900}"
GAP="${PUSH_GAP:-120}"
shas="$(git -C "$work/repo" rev-list --reverse main)"
n="$(printf '%s\n' "$shas" | wc -l | tr -d ' ')"
echo "pushing $n commits in chunks of <=$CHUNK (${GAP}s between pushes)"
i=0; idx=0
while [ "$idx" -lt "$n" ]; do
  i=$((i + 1))
  idx=$((i * CHUNK))
  [ "$idx" -gt "$n" ] && idx="$n"
  sha="$(printf '%s\n' "$shas" | sed -n "${idx}p")"
  [ "$i" -gt 1 ] && sleep "$GAP"
  # chunk 1 may need -f (fresh repo can carry a placeholder README);
  # everything after must be a plain fast-forward
  flag=""; [ "$i" -eq 1 ] && flag="-f"
  GIT_TERMINAL_PROMPT=0 git -C "$work/repo" push -q $flag "$remote" "$sha:refs/heads/main"
  echo "pushed chunk $i ($idx/$n commits)"
done
echo "pushed (chunked) to $safe"
