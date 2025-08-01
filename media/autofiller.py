# autofiller.py
import os
import json
import random
import requests

RADARR_API_KEY = "21d44b12bf484693a8fea99e72b0b6bc"
SONARR_API_KEY = "a73738c180e14b3787e54bcfb6682566"
LIDARR_API_KEY = "pd0bc2b8895a04874b8f81db8ec7ed9ba"
SONARR_URL = "http://192.168.1.85:8989"
RADARR_URL = "http://192.168.1.85:7878"
LIDARR_URL = "http://192.168.1.85:8686"
JELLYFIN_DOC_PATH = "/mnt/netstorage/TV/Wildlife"
MIN_EPISODES = 30

IMPORT_LIST_PATH = "~/Scripts/media/wildlife_watchlist.json"  # local list of shows


def get_episode_count(path):
    count = 0
    for root, _, files in os.walk(path):
        count += len([f for f in files if f.lower().endswith((".mkv", ".mp4", ".avi"))])
    return count


def load_watchlist():
    with open(IMPORT_LIST_PATH) as f:
        return json.load(f)


def request_series_in_sonarr(tvdb_id):
    url = f"{SONARR_URL}/api/series"
    headers = {"X-Api-Key": SONARR_API_KEY}
    payload = {
        "tvdbId": tvdb_id,
        "monitored": True,
        "addOptions": {
            "ignoreEpisodesWithFiles": False,
            "ignoreEpisodesWithoutFiles": False,
            "searchForMissingEpisodes": True,
        },
        "rootFolderPath": "/media/downloads/sonarr",  # where Sonarr writes
        "qualityProfileId": 1,  # adjust to your quality profile
        "seasonFolder": True,
    }
    response = requests.post(url, json=payload, headers=headers)
    print(f"Requested {tvdb_id}: {response.status_code}")
    return response.ok


def main():
    current_count = get_episode_count(JELLYFIN_DOC_PATH)
    print(f"Current wildlife docs: {current_count} episodes")

    if current_count < MIN_EPISODES:
        print("Below limit — adding more...")
        shows = load_watchlist()
        random.shuffle(shows)
        for show in shows:
            if request_series_in_sonarr(show["tvdbId"]):
                print(f"Requested: {show['title']}")
                break
    else:
        print("Sufficient episodes. No action.")


if __name__ == "__main__":
    main()
