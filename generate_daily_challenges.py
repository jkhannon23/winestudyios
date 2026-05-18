#!/usr/bin/env python3
"""
generate_daily_challenges.py
============================
Generates daily-challenges/YYYY-MM-DD.json files for the next N days.

Each JSON file tells the app exactly which questions to show that day,
so every player on every device sees the same set regardless of which
version of the app they have installed.

Usage (run from the repo root):
    python3 generate_daily_challenges.py           # 60 days
    python3 generate_daily_challenges.py --days 90

After running:
    1. Commit and push the daily-challenges/ folder to GitHub.
    2. In DailyChallengeManager.swift set serverBaseURL to:
           https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/daily-challenges
    3. Rebuild and deploy the app.

Question IDs
------------
Each question is identified by a 16-character hex string derived from its
question text using FNV-1a 64-bit — the same algorithm as Question.stableId
in Swift. The ID is stable as long as the question wording doesn't change.
"""

import json
import os
import argparse
from datetime import date, timedelta


# ---------------------------------------------------------------------------
# FNV-1a 64-bit — must match DailyChallengeManager.stableSeed() in Swift
# ---------------------------------------------------------------------------

def fnv1a_64(text: str) -> int:
    h = 0xcbf29ce484222325
    for byte in text.encode("utf-8"):
        h ^= byte
        h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h


def question_id(question_text: str) -> str:
    """16-char hex ID — matches Question.stableId in Swift."""
    return format(fnv1a_64(question_text), "016x")


# ---------------------------------------------------------------------------
# Deterministic selection (Fisher-Yates with xorshift64)
# Matches SeededRandomNumberGenerator + Array.shuffled(using:) in Swift.
# ---------------------------------------------------------------------------

def xorshift64(state: int) -> int:
    state = (state ^ (state << 13)) & 0xFFFFFFFFFFFFFFFF
    state = (state ^ (state >> 7))  & 0xFFFFFFFFFFFFFFFF
    state = (state ^ (state << 17)) & 0xFFFFFFFFFFFFFFFF
    return state


def seeded_shuffle(items: list, seed: int) -> list:
    """
    Replicates Swift's Array.shuffled(using:) with xorshift64 RNG.

    Swift stdlib Fisher-Yates: for i from (n-1) down to 1,
      pick j in [0, i] using bounded rejection sampling,
      swap items[i] and items[j].

    Swift's Int.random(in: 0...i) uses an unbiased bounded method that
    may call next() more than once per iteration. We replicate it here.
    """
    result = list(items)
    state = seed if seed != 0 else 1   # xorshift undefined for state=0

    def next_state():
        nonlocal state
        state = xorshift64(state)
        return state

    n = len(result)
    for i in range(n - 1, 0, -1):
        bound = i + 1  # want j in [0, i] → bound = i+1 values

        # Unbiased bounded generation:
        # threshold = 2^64 % bound — the number of "biased" values at the low end.
        # Reject r if r < threshold; almost all draws are accepted (prob ≈ bound/2^64).
        threshold = (2**64) % bound
        while True:
            r = next_state()
            if r >= threshold:
                break
        j = r % bound

        result[i], result[j] = result[j], result[i]

    return result


def select_questions(question_ids: list, count: int, date_str: str) -> list:
    seed = fnv1a_64(date_str)
    shuffled = seeded_shuffle(question_ids, seed)
    return shuffled[:count]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate daily challenge JSON files."
    )
    parser.add_argument(
        "--days", type=int, default=60,
        help="Number of days to generate starting from today (default: 60)"
    )
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    questions_path = os.path.join(
        script_dir, "winestudyios", "questions.json"
    )

    with open(questions_path, encoding="utf-8") as f:
        questions = json.load(f)

    all_ids = [question_id(q["question"]) for q in questions]

    out_dir = os.path.join(script_dir, "daily-challenges")
    os.makedirs(out_dir, exist_ok=True)

    today = date.today()
    count = 10

    for delta in range(args.days):
        day = today + timedelta(days=delta)
        date_str = day.strftime("%Y-%m-%d")

        selected = select_questions(all_ids, count, date_str)

        payload = {
            "date": date_str,
            "questionIds": selected,
        }

        out_path = os.path.join(out_dir, f"{date_str}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)

        print(f"  {date_str}  {selected}")

    print(f"\n✓ Generated {args.days} files in {out_dir}/")
    print()
    print("Next steps:")
    print("  1. git add daily-challenges/ && git commit && git push")
    print("  2. In DailyChallengeManager.swift set serverBaseURL to:")
    print("       https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/daily-challenges")
    print("  3. Rebuild and push a new build to TestFlight.")


if __name__ == "__main__":
    main()
