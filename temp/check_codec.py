#!/usr/bin/env python3
"""
Check which media files are likely to require transcoding on Jellyfin + Raspberry Pi 4.

- ✅ Works best with H.264 video, AAC/AC3/MP3 audio, and MP4/M4V/MOV containers.
- ❌ Flags H.265, VP9, AV1, DTS, FLAC, unknown codecs, or exotic containers.

Usage:
    ./jellyfin_transcode_check.py /path/to/media
"""

import os
import sys
import re
from pathlib import Path
from pprint import pprint

SUPPORTED_VIDEO = {"h264"}
SUPPORTED_AUDIO = {"aac", "ac3", "mp3"}
SUPPORTED_CONTAINER = {"mp4", "m4v", "mov"}

VIDEO_PATTERNS = {
    "h264": re.compile(r"h\.?264|x264", re.IGNORECASE),
    "h265": re.compile(r"h\.?265|hevc|x265", re.IGNORECASE),
    "vp9": re.compile(r"vp9", re.IGNORECASE),
    "av1": re.compile(r"av1", re.IGNORECASE),
}

AUDIO_PATTERNS = {
    "aac": re.compile(r"aac", re.IGNORECASE),
    "ac3": re.compile(r"ac3|dolby", re.IGNORECASE),
    "mp3": re.compile(r"mp3", re.IGNORECASE),
    "flac": re.compile(r"flac", re.IGNORECASE),
    "dts": re.compile(r"dts", re.IGNORECASE),
}


def guess_codec(name: str, patterns: dict) -> str:
    for codec, regex in patterns.items():
        if regex.search(name):
            return codec
    return "unknown"


def scan_media(root: Path):
    report = []
    for file in root.rglob("*.*"):
        if not file.is_file():
            continue

        ext = file.suffix.lower().lstrip(".")
        fname = file.name

        video_codec = guess_codec(fname, VIDEO_PATTERNS)
        audio_codec = guess_codec(fname, AUDIO_PATTERNS)
        container_ok = ext in SUPPORTED_CONTAINER

        needs_transcode = (
            video_codec not in SUPPORTED_VIDEO
            or audio_codec not in SUPPORTED_AUDIO
            or not container_ok
        )

        report.append(
            {
                "file": str(file.relative_to(root)),
                "container": ext,
                "video": video_codec,
                "audio": audio_codec,
                "transcode": needs_transcode,
            }
        )

    return report


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: jellyfin_transcode_check.py /path/to/media")
        sys.exit(1)

    media_root = Path(sys.argv[1])
    if not media_root.exists():
        print(f"Directory not found: {media_root}")
        sys.exit(1)

    results = scan_media(media_root)
    flagged = [r for r in results if r["transcode"]]

    print(
        f"\n🔎 Found {len(results)} media files. {len(flagged)} flagged for likely transcoding:\n"
    )
    pprint(flagged)
