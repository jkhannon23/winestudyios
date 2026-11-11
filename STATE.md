# Volo — STATE

_Single source of truth. Every session starts here._

Volo is a WSET Level 3 quiz app (iOS, UIKit, repo `jkhannon23/winestudyios`). Live, about 6 installs.
Jill keeps the look and feel (puffin, colours, Nunito, sounds). The layout is too simple and static:
the plan below gives it life, mostly through maps.

## ▶ DECIDED (Jill, 11 Nov 2026)
Build in this order, one step at a time, tested between each:

1. **Questions load from GitHub** (like the daily challenges already do), with a new optional
   `place` field per question. ← START HERE
2. **Map after each answer** — the answer's place shown on a map with a pin.
3. **Drill by topic** — pick one region/category to quiz on.
4. **Progress map** — regions coloured by how well they're known (from the spaced-repetition stats).
5. **Map questions** ("Which pin is Rully?") and **region outlines** where good open data exists.

Alongside, no code: **rebalance the question bank** (see Content below), adding places as questions
are written or checked.

**NOT NOW (Jill):** short-answer practice, exam countdown.
**OPEN:** map look — real Apple map (MapKit) or simple illustrated maps in Volo's colours.

## Step 1 — questions from GitHub
Today `winestudyios/questions.json` is bundled, so every content change needs an App Store build.
- Fetch the questions from `https://raw.githubusercontent.com/jkhannon23/winestudyios/main/content/questions.json`
  (new folder `content/`, so old app versions keep using their bundled copy untouched).
- Cache the last good download on the phone; if offline or the file is broken, use the cache, then the
  bundled copy. Never show an empty quiz.
- Check the file before using it (valid JSON, every question has 4 answers and a correct index in range);
  reject the whole file if not, keep the old set.
- New optional field per question, ignored if missing:
  `"place": { "name": "Rully", "lat": 46.87, "lon": 4.75 }`
- `category` stays as is and is the grouping for drilling and the progress map.
- Question IDs come from the question TEXT (FNV-1a, `Question.stableId`, matching
  `generate_daily_challenges.py`). Changing a question's wording changes its ID and resets its
  spaced-repetition history; any daily challenge using the old ID falls back to the random pick for
  that day. After editing questions: regenerate the daily challenges.
- `generate_daily_challenges.py` should read `content/questions.json` once it exists.
- Jill works in the GitHub web UI only: content updates = upload the edited file and commit to `main`.

## Content — the question bank (460 questions, 11 Nov)
All four-option multiple choice. By category: Spain 46, Burgundy 36, USA 36, Chile 33, Australia 31,
Loire 29, Rhône 29, Bordeaux 28, Germany 27, Argentina 24, **Italy 20**, South Africa 19, Austria 17,
New Zealand 16, Southern France 15, Alsace 13, Portugal 11, South West France 7, Greece 6,
**Fortified 6**, **Champagne 4**, **Grape Varieties 3**, Hungary 2, Canada 2.
Gaps against the Level 3 syllabus: sparkling, fortified, Italy, and nothing yet on vineyard,
winemaking or tasting (SAT). Rebalance in small batches; add `place` where a question is about somewhere.

## Maps — notes
- Pins: MapKit, built in, free; needs only `place` on each question.
- Outlines: France's AOC boundaries are published as open data; there is an open US AVA mapping project;
  Italy and others are patchier. Add region by region.
- Don't trace or copy WSET's maps (copyrighted). Real map data or our own drawings only.

## Daily challenges
Files in `daily-challenges/` run through **13 Feb 2027** (14 Nov–13 Feb uploaded by Jill, 11 Nov).
Make the next batch in early February (`python3 generate_daily_challenges.py --days 90`, skipping dates
that already exist).
