#!/usr/bin/env python3
"""
Forge: one-time script to find a YouTube video id for each exercise.

Setup (once):
    pip install requests
    export YOUTUBE_API_KEY="your_key_here"        # Mac/Linux
    $env:YOUTUBE_API_KEY="your_key_here"          # Windows PowerShell

Run (repeat daily until it says ALL DONE):
    python3 fetch_youtube_ids.py

Output:
    yt_cache.json   { "<exercise id>": "<11-char video id>" }  -> goes into the app
    yt_review.csv   id, name, video id, title, channel, url    -> use it to spot-check
"""

import csv
import json
import os
import sys
import time

import requests

# ---------------- EDIT THESE 3 LINES IF NEEDED ----------------
EXERCISES_FILE = "../../assets/exercises.json"  # path to your exercises JSON
ID_FIELD = "id"                     # field holding the unique exercise id
NAME_FIELD = "name"                 # field holding the exercise name
# --------------------------------------------------------------

CACHE_FILE = "yt_cache.json"
REVIEW_FILE = "yt_review.csv"
SEARCH_URL = "https://www.googleapis.com/youtube/v3/search"

# Each search costs 100 quota units. Default free quota is ~10,000/day,
# so ~100 searches. Stay a little under so the run ends cleanly.
MAX_SEARCHES_PER_RUN = 95

API_KEY = os.environ.get("YOUTUBE_API_KEY")


def load_exercises():
    with open(EXERCISES_FILE, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for value in data.values():
            if isinstance(value, list):
                return value
    sys.exit(f"Could not find a list of exercises in {EXERCISES_FILE}")


def load_cache():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_cache(cache):
    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        json.dump(cache, f, indent=2, ensure_ascii=False)


def append_review(row):
    new_file = not os.path.exists(REVIEW_FILE)
    with open(REVIEW_FILE, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if new_file:
            writer.writerow(["id", "name", "video_id", "title", "channel", "url"])
        writer.writerow(row)


def main():
    if not API_KEY:
        sys.exit("Set YOUTUBE_API_KEY first (see the top of this file).")

    exercises = load_exercises()
    first = exercises[0]
    if ID_FIELD not in first or NAME_FIELD not in first:
        sys.exit(
            f"Fields '{ID_FIELD}' / '{NAME_FIELD}' not found. "
            f"Your exercise fields are: {list(first.keys())}. "
            "Edit ID_FIELD and NAME_FIELD at the top of this file."
        )

    cache = load_cache()
    todo = [e for e in exercises if str(e[ID_FIELD]) not in cache]
    print(f"{len(cache)} done, {len(todo)} remaining, searching up to {MAX_SEARCHES_PER_RUN} now.")

    searches = 0
    for ex in todo:
        if searches >= MAX_SEARCHES_PER_RUN:
            print("Daily limit for this run reached. Run again tomorrow.")
            break

        ex_id = str(ex[ID_FIELD])
        name = str(ex[NAME_FIELD]).strip()

        params = {
            "part": "snippet",
            "type": "video",
            "maxResults": 1,
            "videoEmbeddable": "true",
            "videoDuration": "short",
            "relevanceLanguage": "en",
            "q": f"{name} exercise proper form",
            "key": API_KEY,
        }

        try:
            r = requests.get(SEARCH_URL, params=params, timeout=20)
        except requests.RequestException as e:
            print(f"Network error on '{name}': {e}. Stopping, run again.")
            break

        searches += 1

        if r.status_code != 200:
            try:
                err = r.json()["error"]
                reason = err["errors"][0].get("reason", "")
                message = err.get("message", "")
            except Exception:
                reason, message = "", r.text[:200]
            if reason in ("quotaExceeded", "dailyLimitExceeded", "rateLimitExceeded"):
                print("Quota used up for today. Run again tomorrow.")
            else:
                print(f"API error ({r.status_code}, {reason}): {message}")
                print("Check: API enabled in Google Cloud, key correct, key restrictions.")
            break

        items = r.json().get("items", [])
        if not items:
            print(f"  no result: {name}")
            time.sleep(0.2)
            continue

        item = items[0]
        video_id = item["id"]["videoId"]
        snippet = item["snippet"]
        cache[ex_id] = video_id
        save_cache(cache)
        append_review([
            ex_id, name, video_id, snippet.get("title", ""),
            snippet.get("channelTitle", ""),
            f"https://www.youtube.com/watch?v={video_id}",
        ])
        print(f"  ok: {name} -> {video_id}")
        time.sleep(0.2)

    remaining = len([e for e in exercises if str(e[ID_FIELD]) not in cache])
    if remaining == 0:
        print("ALL DONE.")
    else:
        print(f"Saved. {len(cache)} done, {remaining} remaining.")


if __name__ == "__main__":
    main()
