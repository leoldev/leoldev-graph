#!/usr/bin/env bash
# Daily top-up: fill the CURRENT week's column as the days pass.
#
# Why this exists: the graph is a rolling 53-week window.  Between weekly
# re-anchors the newest column (this week) would otherwise show empty
# cells for days that have already happened, making the art look ragged
# at its right edge.  Within a single week the grid dates are FIXED
# (they anchor to the Sunday), so we don't rebuild — we just append the
# commits for the days of THIS week that are <= today and don't have an
# art commit yet.  That is at most 6 tiny commits, one push.
#
#   daily-topup.sh                 -> run it (idempotent)
#   FORCE=1 daily-topup.sh         -> rebuild the whole current week
#   DRY_RUN=1 daily-topup.sh       -> show what would be added, don't push
#
# It is SAFE to run daily: it only ever ADDS commits dated today or
# earlier in the current week, on top of whatever the repo already has.
# It never rewrites history, so it does not fight the weekly purge (which
# runs a full rebuild on Sunday).
set -euo pipefail
# launchd gives us PATH=/usr/bin:/bin:/usr/sbin:/sbin — no Homebrew, so
# `gh` would be "command not found" when this runs unattended.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(dirname "$0")"
REPO="${ART_REPO:-leoldev/leoldev-graph}"
DRY="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The full intended plan for the current window (dates are stable within a week).
python3 encode.py --plan "$work/plan.tsv"

git init -q -b main "$work/repo"
git -C "$work/repo" config user.name  "${ART_NAME:-leoldev}"
git -C "$work/repo" config user.email "${ART_EMAIL:-341686751+leoldev@users.noreply.github.com}"

# Seed the repo with its real history so we can inspect what dates it
# already has art for, without rewriting anything.
remote_url="${REMOTE_URL:-https://x-access-token:$(gh auth token 2>/dev/null || true)@github.com/${REPO}.git}"
if ! git -C "$work/repo" remote add origin "$remote_url" 2>/dev/null; then
  git -C "$work/repo" remote set-url origin "$remote_url"
fi
git -C "$work/repo" fetch -q --depth=4000 origin main || {
  echo "topup: fetch failed — is $REPO reachable?" >&2; exit 1; }
git -C "$work/repo" reset -q --hard origin/main

# We ONLY top up the CURRENT week.  Older weeks are already complete (the
# weekly purge rebuilds them).  Within a week the grid dates are fixed, so
# "this week" = the Sunday-anchored days from this_sunday(today)..today.
this_sunday="$(python3 -c 'import encode,datetime as d; print(encode.this_sunday(d.date.today()))')"

# GitHub's own live count for each day.  The account is used for real work,
# so a day may ALREADY carry commits from other repos.  Seeding the blind
# design count on top of those overshoots the day (e.g. 10 art + 1 real
# = 11), which raises the graph's max and dims the whole background.  So we
# seed only the DEFICIT: target - already_there, never below zero.
python3 encode.py --existing "$work/live.tsv" >/dev/null

added=0; skipped=0
while IFS=$'\t' read -r d count; do
  if [ "$d" \< "$this_sunday" ]; then continue; fi          # older week: done
  have="$(awk -F'\t' -v k="$d" '$1==k{print $2}' "$work/live.tsv")"
  have="${have:-0}"
  need=$(( count - have ))
  if [ "$need" -le 0 ]; then
    skipped=$((skipped + 1)); continue
  fi
  echo "  ${d}: have ${have}, target ${count} -> seeding ${need}"
  for ((i = 0; i < need; i++)); do
    GIT_AUTHOR_DATE="${d}T12:00:00+0000" GIT_COMMITTER_DATE="${d}T12:00:00+0000" \
      git -C "$work/repo" commit -q --allow-empty -m "art ${d}"
    added=$((added + 1))
  done
done < "$work/plan.tsv"

echo "topup (current week from $this_sunday): $added commit(s) to add, $skipped day(s) already at target"
if [ "$added" -eq 0 ]; then
  echo "topup: nothing to do (current week already fully topped up)"
  exit 0
fi
git -C "$work/repo" log --format='%ad %s' --date=short -n "$added"

if [ "$DRY" = 1 ]; then
  echo "DRY_RUN=1 -> not pushing"
  exit 0
fi

# Only today's cell(s) ever get appended live, so a single small push is
# fine (well under the indexer's per-push event cap).
GIT_TERMINAL_PROMPT=0 git -C "$work/repo" push -q origin HEAD:main
echo "topup: pushed $added commit(s) to $REPO (graph updates within ~24h)"