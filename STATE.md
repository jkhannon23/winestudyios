# Volo — STATE

_Single source of truth. Every session starts here._

Volo is a WSET Level 3 quiz app (iOS, UIKit, repo `jkhannon23/winestudyios`). Live, about 6 installs.
Jill keeps the look and feel (puffin, colours, Nunito, sounds). The layout is too simple and static:
the plan below gives it life, mostly through maps.

## ▶ DECIDED (Jill, 11 Nov 2026)
Build in this order, one step at a time, tested between each:

1. **Questions load from GitHub** (like the daily challenges already do), with a new optional
   `place` field per question. ✅ DONE — merged to `main` and tested live 11 Nov (not yet in an App Store build; see "Step 1 — status").
2. **Map after each answer** — the answer's place shown on a map with a pin.
3. **Drill by topic** — pick one region/category to quiz on.
4. **Progress map** — regions coloured by how well they're known (from the spaced-repetition stats).
5. **Map questions** ("Which pin is Rully?") and **region outlines** where good open data exists.

Alongside, no code: **rebalance the question bank** (see Content below), adding places as questions
are written or checked.

**NOT NOW (Jill):** short-answer practice, exam countdown.
**DECIDED (Jill, 11 Nov):** map look = **real Apple map (MapKit)**, muted style, Volo-pink pin with the
wine-glasses icon, rounded card under the feedback. Chosen over a drawn map after seeing both as simulator
mock-ups (drawn = more Volo, but only shows where in France, not where in Burgundy; needs a drawing per region).
Drawn close-ups can still be added region by region later; the `place` data is the same.

## Step 1 — status (11 Nov 2026)
**Done (merged to `main` 11 Nov, PR #1; not yet on the phone or in an App Store build):**
- `content/questions.json` created (identical to the bundled file: 460 questions, no wording changed, so
  all question IDs and spaced-repetition history are unchanged). The bundled `winestudyios/questions.json`
  stays as the last-resort fallback.
- App (`Question.swift`, one line in `ViewController.swift`): quiz starts at once from the saved copy on the
  phone, else the bundled one; in the background it downloads the GitHub file and, only if it passes every
  check, saves it for next time and uses it. A quiz already started keeps its own questions.
- Checks (whole file rejected if any fails): valid JSON list, at least 20 questions, every question has text,
  exactly 4 non-empty answers, correct index 0–3, feedback present, no two questions with the same text.
- `place` is optional. A broken `place` (bad numbers, wrong shape) is dropped quietly and the question stays.
  No question has a `place` yet.
- `generate_daily_challenges.py` reads `content/questions.json` (falls back to the bundled file if missing).
- The App Store app is unaffected: it never reads `content/`.

**Tested:**
- Checks vs good/broken files (13 cases, all pass).
- Simulator, before merge: bundled fallback (GitHub 404), saved copy used, broken saved copy ignored → bundled.
- Simulator, after merge: app downloads the live file and saves an identical copy. Jill edited a question on
  GitHub → app picked it up on next launch; Jill undid it → app picked that up too. File on `main` is back
  to the original.
- Generator reads the new file. Home and quiz screens look like the App Store version (Nunito, close button).

**Not tested:** a deliberately broken file uploaded to GitHub itself (only tested with broken files planted
in the simulator); a real phone. Next App Store build: TestFlight first, then check a quiz on the phone.

**GitHub delay:** after a commit, `raw.githubusercontent.com` can serve the OLD file for up to ~5 minutes.
So a fix shows in the app on the first launch after that, not instantly. Nothing to do about it.

**How Jill edits questions from now on:** edit `content/questions.json` on GitHub (pencil icon → commit to
`main`). That is the live file. The copy inside the app is only the safety net; refresh it at each App Store build.
Editing answers or feedback is safe. Editing question *wording* changes that question's ID: its history resets
and any daily challenge using it falls back to a random pick → regenerate daily challenges afterwards.

**Heads-up (found 11 Nov, now fixed):** GitHub was behind the App Store app. Edits made 31 May–2 Jun
(smaller button padding, daily-challenge "completed" view, font path fix so Nunito loads, display name set in
project settings, iPhone-only) were never committed. They are now on `main` (came in with PR #1). Branches
`shipped-app-edits` and `step1-questions-from-github` are merged and can be deleted.

**NEXT:** step 2, map after each answer, Apple map (decided above). Use Opus for map work.
- Build the card for real: shown only when the question has a `place`, hidden otherwise; no map = layout as today.
- Card height/position to settle on the phone: in the mock it sat under the feedback and needed a small scroll.
- Add `place` to a first batch of questions (e.g. Burgundy) in `content/questions.json` so there is something to see.
- Offline: the map area is blank without signal; the quiz itself still works.
- Mock-up code (throwaway, local only): branch `mock-map`, `.claude/worktrees/mock-map`.

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
