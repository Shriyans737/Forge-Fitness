# YouTube exercise tutorial IDs

Run these commands from the project root on macOS:

```sh
pip3 install requests
export YOUTUBE_API_KEY="..."
cd tools/youtube_ids && python3 fetch_youtube_ids.py
```

Run once per day until the script prints `ALL DONE`. Then copy
`yt_cache.json` to `assets/data/youtube_ids.json`.
