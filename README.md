# leoldev-graph

**Contribution art built to survive real activity on the account.**
White pixel text `@leoldev` followed by a 9×7 LinkedIn frame (open top and
bottom, `in` inside), on a 53 × 7 board with a **dark green field** and
**lighter lettering**:

- background cells → **10 commits/day** → GitHub's darkest shade (FOURTH quartile)
- text / frame cells → **1 commit/day** → GitHub's lightest shade (FIRST quartile)

```
🟦🟦🟦🟦🟩🟩🟩🟦🟦🟩🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦🟩🟦🟦🟦🟦🟩🟦🟦🟦🟦🟩🟦🟦🟦🟦🟩🟦🟦🟦🟦🟦🟦🟩🟦🟦🟦🟦🟦
🟦🟦🟦🟩🟦🟦🟦🟩🟦🟩🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦🟩🟦🟦🟦🟦🟩🟦🟦🟦🟦🟩🟦🟦🟦🟦🟦🟦🟩🟦🟦🟦🟦🟩🟦🟦🟦
🟦🟦🟦🟩🟦🟩🟩🟩🟦🟩🟦🟦🟩🟩🟦🟦🟦🟩🟩🟦🟦🟩🟦🟩🟦🟦🟩🟩🟩🟦🟦🟩🟩🟦🟦🟩🟦🟩🟦🟩🟦🟦🟦🟩🟦🟦🟦🟦🟦🟦🟩🟦🟦🟦
🟦🟦🟦🟩🟦🟩🟦🟩🟦🟩🟦🟩🟦🟦🟩🟦🟩🟦🟦🟩🟦🟩🟦🟦🟩🟦🟩🟦🟩🟦🟦🟦🟩🟦🟦🟦🟦🟩🟦🟩🟩🟦🟩🟦🟩🟩🟦🟩🟦🟩
🟦🟦🟦🟩🟦🟩🟩🟩🟦🟩🟦🟩🟩🟩🟩🟦🟩🟦🟦🟩🟦🟩🟦🟩🟦🟩🟩🟦🟩🟦🟩🟩🟩🟦🟦🟩🟦🟦🟩🟦🟩🟦🟩🟩🟩🟩🟦🟩🟦🟩🟦🟩
🟦🟦🟦🟩🟦🟦🟦🟩🟦🟩🟦🟩🟦🟦🟦🟦🟩🟦🟦🟩🟦🟩🟦🟩🟦🟩🟦🟩🟦🟩🟦🟦🟩🟦🟩🟦🟩🟦🟩🟦🟦🟩🟩🟩🟦🟦🟩🟦🟦🟦
🟦🟦🟦🟦🟩🟩🟩🟦🟦🟩🟦🟦🟩🟩🟦🟦🟦🟩🟩🟦🟦🟩🟦🟩🟩🟩🟦🟦🟩🟩🟦🟦🟩🟦🟩🟦🟦🟦🟩🟦🟦🟦🟦🟩🟦🟦🟦
```

## Why 10 background / 1 text

This is a real account that gets real work pushed to it, so the design
treats that activity as harmless rather than as a bug:

| day | art | your commits | total | renders as |
|---|---|---|---|---|
| background, quiet | 10 | 0 | 10 | dark green (the field) |
| **text pixel, quiet** | 1 | 0 | 1 | pale green (the lettering) |
| background + a commit | 10 | 1 | 11 | still dark — no visible change |
| **text pixel + 1 commit** | 1 | 1 | 2 | still the same pale shade → hole invisible |
| text pixel + a burst | 1 | 3+ | 4+ | a faint dot (rare) |

Two properties make this work:

1. **A commit that lands on a letter is invisible.** The text cell goes
   1 → 2, still in the lowest band, so the hole disappears into the same
   shade the lettering already uses instead of appearing as a bright dot.
2. **The field can't be dimmed.** GitHub's colour scale is relative to the
   busiest day. Because the field sits at a high count (10), an extra real
   commit on a background day barely moves the max — it stays FOURTH.

A previous all-low-count design broke the second point (the whole field was
pale and the lettering nearly invisible), and an even-earlier high-count
solid broke point 2 badly: one busy day dimmed the entire background. This
10/1 split keeps the field dark *and* absorbs activity.

## How it works

- `encode.py` — the source of truth. Builds the board, maps every cell to a
  date (columns are weeks, rows Sun–Sat), emits the commit plan, and prints
  the design. `verify()` reads GitHub's own per-day `contributionLevel` and
  reports bright dots in the art (a burst landed on a letter), background
  cells that dimmed (a large burst shifted the scale), and indexing lag.
  It reports only; the design now tolerates normal activity.
- `recode.sh` — regenerates the whole history as backdated empty commits and
  pushes it in **chunks of ≤900 commits** (`PUSH_CHUNK`/`PUSH_GAP`, default
  120 s between pushes). GitHub's indexer only runs one ~1,000-event batch per
  push before stalling, so chunked fast-forwards keep every cell indexed.
  `DRY_RUN=1` builds without pushing.
- `purge.sh` — **the weekly reset.** GitHub *retains* contribution events
  across force-pushes, so re-pinning the art to the sliding 53-week window
  needs a real wipe: delete + recreate + re-encode. Idempotent. Needs `gh`
  with the `delete_repo` scope.
- `daily-topup.sh` — **the daily fill.** Within a week the grid dates are
  fixed (they anchor to the Sunday), so the newest column would otherwise go
  blank as the days pass. This appends only the missing commits for the
  *current* week (a few commits, one small push) on top of existing history.
  It never rewrites anything and never fights the weekly purge. Idempotent —
  a second run the same day adds nothing. `DRY_RUN=1` to inspect.
- `weekly-purge.sh` + `~/Library/LaunchAgents/com.ldpleo.graph-purge.plist`
  — launchd job, **Mondays 13:30 local** (03:30 UTC): reads back the render,
  runs `purge.sh` (one retry), logs to `weekly-purge.log`.
- `daily-topup.sh` + `~/Library/LaunchAgents/com.ldpleo.graph-topup.plist`
  — launchd job, **daily 14:00 local**, running after the Monday purge so
  the two don't race. Logs to `daily-topup.launchd.log`.
- `.github/workflows/recode.yml` — read-back only; never pushes.

A workflow *in* this repo can't run the purge: the run dies when the repo is
deleted, and `GITHUB_TOKEN` has no `delete_repo` scope — hence the local jobs.

## Local use

```sh
./recode.sh                    # full rebuild + chunked push
DRY_RUN=1 ./recode.sh          # build only
python3 encode.py --preview    # print the board
python3 encode.py --verify     # read back live levels vs design
./purge.sh                     # manual weekly reset
./daily-topup.sh               # manual daily top-up (usually a no-op)
DRY_RUN=1 ./daily-topup.sh     # show what the top-up would add

# manage the jobs
launchctl print   gui/$(id -u)/com.ldpleo.graph-purge    # weekly reset
launchctl print   gui/$(id -u)/com.ldpleo.graph-topup    # daily fill
launchctl bootout gui/$(id -u)/com.ldpleo.graph-purge    # remove one
launchctl bootout gui/$(id -u)/com.ldpleo.graph-topup
```

## If the Mac is asleep

launchd runs missed calendar jobs when the machine wakes. If the daily
top-up misses a day, the next run backfills the whole current week, and the
weekly purge re-anchors everything anyway. If the Mac stays off past Monday,
run `./purge.sh` once by hand when you get back.

## Removing the art

Delete this repository — its contributions disappear with it (allow 24 h for
the graph to refresh). Boot out both launchd jobs first, or they'll recreate
it on their next scheduled run.