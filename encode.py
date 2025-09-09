#!/usr/bin/env python3
"""
leoldev contribution art — dark field, lighter "@leoldev" + LinkedIn frame.

Board (53 cols x 7 rows).  Every cell gets a commit count:
    text / frame cells  -> TEXT_COUNT = 1  (renders at GitHub's lightest
                          shade, FIRST quartile, against the dark field)
    background cells    -> BAND_COUNT = 10 (renders at the darkest shade,
                          FOURTH quartile)
So the field is dark green and the lettering/frame are pale green on top.

This profile is a real, used account, so the design treats the account's
own activity as harmless:
  * a real commit on a background day bumps 10->11, still FOURTH (dark,
    no visible change) — a busy day cannot "dim" the field the way a
    relative-scale high-count background did;
  * a real commit on a TEXT/FRAME day bumps 1->2, which is still FIRST
    quartile = the same shade the text already renders -> the hole is
    invisible, not a bright dot in a letter;
  * only a burst (3+ on one text day) would show a faint dot, and
    verify() names the date if it ever happens.
verify() reads GitHub's own per-day contributionLevel over the API (no
local threshold math) and reports dimming / dots / indexing lag.
"""
import argparse
import datetime as dt
import json
import os
import subprocess
import sys

W, ROWS = 53, 7

TEXT_COL = 3        # "@" starts here
LOGO_COL = 41       # LinkedIn frame left edge

FONT = {
    "@": [".###.", "#...#", "#.###", "#.#.#", "#.###", "#...#", ".###."],
    "l": ["#", "#", "#", "#", "#", "#", "#"],
    "e": ["....", "....", ".##.", "#..#", "####", "#...", ".##."],
    "o": ["....", "....", ".##.", "#..#", "#..#", "#..#", ".##."],
    "d": ["...#", "...#", ".###", "#..#", "#..#", "#..#", ".###"],
    "v": [".....", ".....", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."],
}
PIECES = ["@", "l", "e", "o", "l", "d", "e", "v"]   # -> "@leoldev"
LOGO = [                                            # 9x7 LinkedIn frame
    ".#.....#.",   # rounded top corners only (open top edge)
    "#.#.....#",   # i-dot inside the frame
    "#.......#",   # gap between i-dot and stem
    "#.#.###.#",   # i stem + n arch
    "#.#.#.#.#",
    "#.#.#.#.#",
    ".#.....#.",   # rounded bottom corners (open bottom edge)
]

# Counts and shades.  TEXT_COUNT cells read pale (FIRST quartile);
# BAND_COUNT cells read dark (FOURTH quartile).
TEXT_COUNT = 1
BAND_COUNT = 10
TEXT_EMOJI = "\U0001f7e9"   # 🟩 pale green  (letters/frame)
BG_EMOJI = "\U0001f7e6"    # 🟦 dark green  (field)

OFF = "\u2b1c"
LEVEL_NAME = {1: "FIRST_QUARTILE", 2: "SECOND_QUARTILE",
              3: "THIRD_QUARTILE", 4: "FOURTH_QUARTILE"}
LEVEL_VALUE = {"NONE": 0, "FIRST_QUARTILE": 1, "SECOND_QUARTILE": 2,
               "THIRD_QUARTILE": 3, "FOURTH_QUARTILE": 4}


def letter_grid():
    """None = background cell; a str = text/frame cell."""
    g = [[None] * W for _ in range(ROWS)]
    c = TEXT_COL
    for i, p in enumerate(PIECES):
        if i:
            c += 1
        for r, row in enumerate(FONT[p]):
            for j, ch in enumerate(row):
                if ch == "#":
                    g[r][c + j] = p
        c += len(FONT[p][0])
    for r, row in enumerate(LOGO):
        for j, ch in enumerate(row):
            if ch == "#":
                g[r][LOGO_COL + j] = "logo"
    return g


def this_sunday(today):
    return today - dt.timedelta(days=(today.weekday() + 1) % 7)


def grid_start(today):
    """First day rendered in the 53-week grid (Sunday, 52 weeks back)."""
    return this_sunday(today) - dt.timedelta(weeks=52)


def live_counts(today, login="leoldev"):
    """GitHub's own per-day contributionCount for the window.

    The account is used for real work, so a day can already carry commits
    from other repos.  The seeder uses this to add only the DEFICIT up to
    the design target, instead of blindly appending a fixed number and
    overshooting the day (which raises the graph's max and dims the art).
    """
    q = (
        "query($login:String!,$from:DateTime!,$to:DateTime!){"
        "user(login:$login){contributionsCollection(from:$from,to:$to){"
        "contributionCalendar{weeks{contributionDays{date contributionCount}}}}}}"
    )
    frm = grid_start(today).isoformat() + "T00:00:00Z"
    to = today.isoformat() + "T23:59:59Z"
    try:
        raw = subprocess.run(
            ["gh", "api", "graphql", "-f", "query=" + q, "-f", "login=" + login,
             "-f", "from=" + frm, "-f", "to=" + to],
            capture_output=True, text=True, timeout=60, check=True,
        ).stdout
    except Exception:
        return {}
    body = json.loads(raw)
    if body.get("errors"):
        return {}
    cal = body["data"]["user"]["contributionsCollection"]["contributionCalendar"]
    out = {}
    for wk in cal["weeks"]:
        for d in wk["contributionDays"]:
            out[dt.date.fromisoformat(d["date"])] = d["contributionCount"]
    return out


def plan(today):
    """[(date, count)] for every rendered cell in the window."""
    letters = letter_grid()
    sun = this_sunday(today)
    earliest = grid_start(today)
    out = []
    for c in range(W):
        wsun = sun - dt.timedelta(weeks=52 - c)
        for r in range(ROWS):
            d = wsun + dt.timedelta(days=r)
            if d > today or d < earliest:
                continue
            cnt = TEXT_COUNT if letters[r][c] is not None else BAND_COUNT
            out.append((d, cnt))
    return out


def expected(today):
    """(fill: date->count, text: set-of-text/frame-dates) in the window."""
    letters = letter_grid()
    sun = this_sunday(today)
    earliest = grid_start(today)
    fill, text = {}, set()
    for c in range(W):
        wsun = sun - dt.timedelta(weeks=52 - c)
        for r in range(ROWS):
            d = wsun + dt.timedelta(days=r)
            if d > today or d < earliest:
                continue
            if letters[r][c] is not None:
                text.add(d)
                fill[d] = TEXT_COUNT
            else:
                fill[d] = BAND_COUNT
    return fill, text


def preview(today=None):
    letters = letter_grid()
    lines = []
    for r in range(ROWS):
        lines.append("".join(TEXT_EMOJI if letters[r][c] is not None else BG_EMOJI
                             for c in range(W)))
    return "\n".join(lines)


def verify(today, login="leoldev"):
    fill, text = expected(today)
    frm = grid_start(today).isoformat() + "T00:00:00Z"
    to = today.isoformat() + "T23:59:59Z"
    q = (
        "query($login:String!,$from:DateTime!,$to:DateTime!){"
        "user(login:$login){contributionsCollection(from:$from,to:$to){"
        "contributionCalendar{totalContributions "
        "weeks{contributionDays{date contributionCount contributionLevel}}}}}}"
    )
    try:
        raw = subprocess.run(
            ["gh", "api", "graphql", "-f", "query=" + q,
             "-f", "login=" + login, "-f", "from=" + frm, "-f", "to=" + to],
            capture_output=True, text=True, timeout=60, check=True,
        ).stdout
    except Exception as e:  # no gh / no network -> skip quietly
        print("verify: skipped (%s)" % e)
        return
    body = json.loads(raw)
    if body.get("errors"):
        print("verify: graphql errors: %s" % body["errors"])
        return
    cal = body["data"]["user"]["contributionsCollection"]["contributionCalendar"]
    total = cal["totalContributions"]
    days = {}
    for wk in cal["weeks"]:
        for d in wk["contributionDays"]:
            days[dt.date.fromisoformat(d["date"])] = (
                d["contributionCount"], d["contributionLevel"])

    lvl = lambda d: LEVEL_VALUE.get(days.get(d, ("", "NONE"))[1], 0)
    # text cells should read FIRST (1); a stray/burst commit can lift them.
    dots = sorted(d for d in text if lvl(d) > 1)
    # background cells should read FOURTH (4); extras keep it there, but a
    # big burst raises the max and can pull the whole field down a band.
    dimmed = sorted(d for d in fill if d not in text and lvl(d) < 4)
    missing = sorted(d for d in fill if days.get(d, (0, "NONE"))[1] == "NONE")
    design_sum = sum(fill.values())

    lines = ["### contribution-art read-back (%s)" % today.isoformat()]
    lines.append("- window total: %d contributions (art %d + your activity %d)"
                 % (total, design_sum, total - design_sum))
    if dots:
        lines.append("- \u26a0\ufe0f **%d text/frame days show a visible dot** "
                     "(2+ of your commits landed on one), e.g. %s"
                     % (len(dots), ", ".join(str(d) for d in dots[:5])))
    else:
        lines.append("- no visible dots in text/frame \u2705")
    if dimmed:
        lines.append("- \u26a0\ufe0f **%d background cells dimmed** (a large burst "
                     "raised the max, shifting the field down a band), e.g. %s"
                     % (len(dimmed), ", ".join(str(d) for d in dimmed[:5])))
    else:
        lines.append("- field stays dark (FOURTH) everywhere \u2705")
    if missing:
        lines.append("- %d cells empty (indexing lag?), e.g. %s .. %s"
                     % (len(missing), missing[0], missing[-1]))
    else:
        lines.append("- every cell indexed \u2705")
    out = "\n".join(lines)
    print(out)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(out + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--plan", metavar="FILE")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--existing", metavar="FILE",
                    help="write GitHub's live date->count for the window")
    ap.add_argument("--today", help="YYYY-MM-DD (testing)")
    ap.add_argument("--login", default="leoldev")
    args = ap.parse_args()
    today = dt.date.fromisoformat(args.today) if args.today else dt.date.today()

    if args.existing:
        live = live_counts(today, args.login)
        with open(args.existing, "w") as f:
            for d, n in sorted(live.items()):
                f.write("%s\t%d\n" % (d.isoformat(), n))
        print("existing: wrote %d day(s) of live counts" % len(live))

    if args.preview:
        print(preview(today))
    if args.plan:
        with open(args.plan, "w") as f:
            for d, n in plan(today):
                f.write("%s\t%d\n" % (d.isoformat(), n))
    if args.verify:
        verify(today, args.login)
    if not (args.preview or args.plan or args.verify or args.existing):
        ap.error("pick --preview, --plan, --existing or --verify")


if __name__ == "__main__":
    main()