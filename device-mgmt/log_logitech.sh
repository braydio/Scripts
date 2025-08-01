#!/usr/bin/env python3
import time
import os
import statistics
from datetime import datetime

DEVICE_PATH = "/dev/input/logitech_dj"
LOG_FILE = "~/Documents/Logitech.log"
MONITOR_DURATION_SEC = 360 # 60 * 60 * 24  # 24 hours
LAG_THRESHOLD_MS = 25  # anything over this = lag spike

def log_event(ts, delay_ms):
    with open(LOG_FILE, "a") as f:
        f.write(f"{ts},{delay_ms:.2f}ms\n")

def monitor_input_lag():
    print(f"[•] Monitoring: {DEVICE_PATH}")
    print(f"[•] Logging to: {LOG_FILE}")
    print(f"[•] Duration: {MONITOR_DURATION_SEC // 60} min")

    delays = []
    last_ts = time.time()

    try:
        with open(DEVICE_PATH, "rb") as f:
            start = time.time()
            while (time.time() - start) < MONITOR_DURATION_SEC:
                data = f.read(24)  # basic input_event struct size

                now = time.time()
                delay = (now - last_ts) * 1000
                last_ts = now
                delays.append(delay)

                # only log significant delays
                if delay > LAG_THRESHOLD_MS:
                    ts_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    log_event(ts_str, delay)

    except PermissionError:
        print("[!] Permission denied. Try with sudo or fix udev.")
    except FileNotFoundError:
        print("[!] Device not found. Is receiver plugged in?")
    except KeyboardInterrupt:
        print("[x] Interrupted by user.")

    # Final summary
    if delays:
        avg = statistics.mean(delays)
        max_d = max(delays)
        spikes = sum(1 for d in delays if d > LAG_THRESHOLD_MS)
        print(f"\n[✓] Done. Total samples: {len(delays)}")
        print(f"    Avg Delay: {avg:.2f}ms")
        print(f"    Max Delay: {max_d:.2f}ms")
        print(f"    Spikes >{LAG_THRESHOLD_MS}ms: {spikes}")

if __name__ == "__main__":
    monitor_input_lag()
