# Volo — STATE

_Single source of truth. Every session starts here._

Volo is a WSET Level 3 quiz app (iOS, UIKit, repo `jkhannon23/winestudyios`). Live, about 6 installs.
Jill keeps the look and feel (puffin, colours, Nunito, sounds). The layout is too simple and static:
the plan below gives it life, mostly through maps.

## ▶ DECIDED (Jill, 11 Nov 2026)
Build in this order, one step at a time, tested between each:

1. **Questions load from GitHub** (like the daily challenges already do), with a new optional
   `place` field per question. ✅ DONE — merged to `main` and tested live 11 Nov (not yet in an App Store build; see "Step 1 — status").
2. **Map after each answer** — the answer's place shown on a map with a pin. 🔨 PART 1 BUILT 11 Nov (map card in the app);
   part 2 = add places to questions: Burgundy done 12 Nov, waiting on Jill's check. See "Step 2 — status".
3. **Drill by topic** — pick one region/category to quiz on.
4. **Progress map** — regions coloured by how well they're known (from the spaced-repetition stats).
5. **Map questions** ("Which pin is Rully?") and **region outlines** where good open data exists.

Alongside, no code: **rebalance the question bank** (see Content below), adding places as questions
are written or checked.

**NOT NOW (Jill):** short-answer practice, exam countdown.

**IDEAS FOR LATER (Jill, not yet ordered):**
- **Score tracker** — see your past scores over time, and see the days you missed (a calendar or streak
  view). Note: today the app only keeps today's daily-challenge score and the streak; past scores are not
  stored yet, so tracking starts from the version that adds it.

**TO FIX (Jill):**
- **Sounds need to be reconsidered** (Jill, 11 Nov). Sounds are part of the look and feel, so nothing changes
  without Jill choosing; start by listing where each sound plays (correct, wrong, next, play again, win, fail).

**RELEASE PLAN (Jill, 11 Nov):** no new App Store version until the app is much more robust. Meanwhile
test on Jill's phone with **Volo Dev** (see below), not through the App Store.
**DECIDED (Jill, 11 Nov):** map look = **real Apple map (MapKit)**, muted style, Volo-pink pin with the
wine-glasses icon, rounded card under the feedback. Chosen over a drawn map after seeing both as simulator
mock-ups (drawn = more Volo, but only shows where in France, not where in Burgundy; needs a drawing per region).
Drawn close-ups can still be added region by region later; the `place` data is the same.

## Volo Dev — test copy on Jill's phone (11 Nov 2026)
- Test builds (Xcode "Debug", what Run in Xcode puts on the phone) are now a separate app: name **Volo Dev**,
  app id `jill.winestudyios.dev`. They sit NEXT TO the real Volo, with their own progress/streak.
- App Store builds (Archive → "Release") are unchanged: **Volo**, `jill.winestudyios`. Checked with Xcode's
  build settings; only the two Debug lines in `project.pbxproj` changed.
- Same icon for both; the name under the icon tells them apart.
- To put it on the phone: plug in the phone (or same Wi-Fi), Developer Mode on, pick the phone in Xcode, Run.
- ✅ Installed on Jill's iPhone 11 Nov; Jill confirmed it looks right and sits next to the real Volo.
  Test installs stop opening after about a year → just reinstall.

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

**NEXT:** see "Step 2 — status" below.

## Step 2 — status (11 Nov 2026)
**Part 1 done (merged to `main` 11 Nov, PR #2; not yet on the phone):**
- `PlaceMapCard.swift`: muted Apple map in a rounded card (pink edge), Volo-pink pin with the wine-glasses
  icon and the place name. Zoom: about 50 km across (Jill chose closer over wide, 11 Nov), so nearby
  villages (Rully, Mercurey, Givry, Montagny) show as different spots; pinch out for the bigger picture. Pinch to zoom
  and drag to slide (sliding added 12 Nov after Jill tried it on her phone; before, dragging was off). A swipe that
  starts on the map moves the map; swipe above/below it to scroll the page. Each new answer re-centres on its pin.
- Shown under the feedback ONLY when the question has a `place`. No place → no map, no gap: exactly as before.
- Fix: after answering, the page now scrolls far enough to show the whole map (it measured too early).
- Testing aid (DEBUG builds only, never in the App Store app): launch argument `-skipQuestionRefresh`.
- **"Map questions only" switch** (12 Nov, DEBUG/Volo Dev only): launch once with `-pinsOnlyOn` and Play uses
  only questions with a `place` (every answer shows a map); it is remembered until a launch with `-pinsOnlyOff`.
  Daily challenge is not affected. Turned ON on Jill's phone 12 Nov
  (`xcrun devicectl device process launch --device <phone> jill.winestudyios.dev -- -pinsOnlyOn`). Ask Claude to turn it off.
  It goes away by itself when step 3 (drill by topic) gives a proper way to pick questions.

**Tested in the simulator** with a sample file (the 36 Burgundy questions, 17 with places; never uploaded):
map after a right answer (Meursault), after a wrong answer (Montagny, map moves to the new place),
Moulin-à-Vent; question without a place shows no map and no gap. Look and feel unchanged otherwise.

**Nobody sees a map yet:** no question on GitHub has a `place`, and the App Store app doesn't have this code.

**Left to decide / test:**
- Offline: map area blank without signal (not yet checked on screen).
- On the phone (after merge + TestFlight).

**Part 2 — Burgundy places added (12 Nov, branch `step2-burgundy-places`):** 21 of the 36 Burgundy
questions in `content/questions.json` now have a `place`. Jill chose to add them first and check them
later in Volo Dev with her reference books (only Volo Dev reads this file; the App Store app never does).
Pins (lat, lon): Chablis 47.815, 3.798 (7 questions) · Rully 46.875, 4.746 (2) · Montagny 46.710, 4.680 (2) ·
Meursault 46.977, 4.770 (2) · Mercurey 46.840, 4.716 · Givry 46.782, 4.743 · Volnay 47.000, 4.776 ·
Pouilly-Fuissé 46.283, 4.745 · Saint-Véran 46.255, 4.725 · Roche de Solutré 46.297, 4.718 ·
Mâcon 46.307, 4.832 (for "Mâcon Villages") · Moulin-à-Vent 46.194, 4.743.
Montagny and Volnay were moved from the first draft (Montagny was on Buxy; Volnay was ~2 km north).
Rule: a question gets a pin only when its answer is a place; the pin is where that place really is
(so "Which village is not in Beaujolais? → Montagny" shows Montagny up north). General questions get none.
Adding `place` doesn't change question IDs.
Tested in the simulator with the new file: Mâcon pin shows; a no-pin question shows no map; whole file
passes the app's checks (460 questions, 21 with places).

**TO CHECK (Jill, with reference books, in Volo Dev):** every pin above, and whether to keep the two
judgement calls: Mâcon Villages → pin on Mâcon town; "not in Beaujolais → Montagny" has a pin.
To fix a pin: edit its `lat`/`lon` in `content/questions.json` on GitHub (or ask Claude).

**NEXT:** after Jill's check, places for the next region (pick one).

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

## Step 2 part 2 — Italy places (12 Nov, branch `step2-italy-places`)
Jill picked Italy next because she can check it without her books. 19 of the 20 Italy questions in
`content/questions.json` now have a `place` (rule: the question is about one place; the pin is that place).
Pins (lat, lon): Alto Adige 46.498, 11.355 (on Bolzano; 3 questions) · Bolzano (same spot; 1) ·
Trentino 46.068, 11.121 (on Trento; 2) · Friuli-Venezia Giulia 46.063, 13.235 (on Udine; 3) ·
Collio 45.956, 13.468 (on Cormons) · Valpolicella 45.517, 10.886 (on San Pietro in Cariano; 2) ·
Barolo 44.611, 7.943 · Barbaresco 44.726, 8.082 · Frascati 41.809, 12.680 · Vulture 40.927, 15.672
(on Rionero in Vulture) · Montepulciano 43.099, 11.787 · Scansano 42.688, 11.330 (Morellino) ·
Montefalco 42.892, 12.652 (Sagrantino).
No pin: "What best describes Teroldego wines?" (a grape question).
Tested in the simulator: Friuli pin shows; file passes the app's checks.
**TO CHECK (Jill):** every pin; whole-region questions (Alto Adige, Trentino, Friuli) pin the main town.

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
