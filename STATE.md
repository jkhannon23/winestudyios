# Volo — STATE

_Single source of truth. Every session starts here._

Volo is a WSET Level 3 quiz app (iOS, UIKit, repo `jkhannon23/winestudyios`). Live, about 6 installs.
Jill keeps the look and feel (puffin, colours, Nunito, sounds). The layout is too simple and static:
the plan below gives it life, mostly through maps.

## ▶ DECIDED (Jill, 11 Nov 2026)
Build in this order, one step at a time, tested between each:

1. **Questions load from GitHub** (like the daily challenges already do), with a new optional
   `place` field per question. ✅ BUILT 11 Nov on branch `step1-questions-from-github` — waiting for Jill to test and merge (see "Step 1 — status").
2. **Map after each answer** — the answer's place shown on a map with a pin.
3. **Drill by topic** — pick one region/category to quiz on.
4. **Progress map** — regions coloured by how well they're known (from the spaced-repetition stats).
5. **Map questions** ("Which pin is Rully?") and **region outlines** where good open data exists.

Alongside, no code: **rebalance the question bank** (see Content below), adding places as questions
are written or checked.

**NOT NOW (Jill):** short-answer practice, exam countdown.
**OPEN:** map look — real Apple map (MapKit) or simple illustrated maps in Volo's colours.

## Step 1 — status (11 Nov 2026)
**Done (branch `step1-questions-from-github`, not merged, not on the phone):**
- `content/questions.json` created (identical to the bundled file: 460 questions, no wording changed, so
  all question IDs and spaced-repetition history are unchanged). The bundled `winestudyios/questions.json`
  stays as the last-resort fallback.
- App (`Question.swift`, one line in `ViewController.swift`): quiz starts at once from the saved copy on the
  phone, else the bundled one; in the background it downloads the GitHub file and, only if it passes every
  check, saves it for next time and uses it. A quiz already started keeps its own questions.
- Checks (whole file rejected if any fails): valid JSON list, at least 20 questions, every question has text,
  exactly 4 non-empty answers, correct index 0–3, feedback present, no two questions with the same text.
- `place` is optional. A broken `place` (bad numbers, wrong shape) is dropped quietly and the question stays.
- `generate_daily_challenges.py` reads `content/questions.json` (falls back to the bundled file if missing).

**Tested:** checks vs good/broken files (13 cases, all pass); simulator: bundled fallback (GitHub 404 before
the file exists), saved copy used, broken saved copy ignored → bundled used; generator reads the new file.
Home screen and quiz screens look unchanged.

**Left to test (after merge, when the file is live on GitHub):**
1. Merge the branch → `content/questions.json` appears on `main`.
2. In the simulator: edit one question's *answer text* in the GitHub web UI, relaunch twice → the change shows
   (first launch downloads, second launch uses the saved copy; a quiz in progress is not affected).
3. Airplane mode → quiz still works. Upload a deliberately broken file → app keeps the old questions.
4. Then TestFlight build, since old app versions don't have this.

**How Jill edits questions from now on:** edit/upload `content/questions.json` on GitHub (that is the live
file). The copy inside the app is only the safety net; refresh it at each App Store build. After editing
question *wording*: regenerate daily challenges (see Daily challenges).

**Heads-up (found 11 Nov):** GitHub was BEHIND the App Store app. Edits made 31 May–2 Jun (smaller button
padding, daily-challenge "completed" view, font path fix so Nunito loads, display name set in project settings,
iPhone-only) were never committed. They are now saved on branch `shipped-app-edits`, and Step 1 is built on top
of it, so building from Step 1 keeps the shipped look. **Merge `shipped-app-edits` first, then Step 1** (Step 1
contains both, so merging Step 1 alone also works). Simulator check: Nunito shows on home and quiz screens.

**NEXT:** step 2, map after each answer. **Switch to Opus for the map work** (and decide the OPEN question:
real Apple map vs illustrated maps).

## Step 1 — the original brief
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
