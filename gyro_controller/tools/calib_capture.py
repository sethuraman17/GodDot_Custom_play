#!/usr/bin/env python3
"""Capture a labelled window of live controller state and print stats.

Run while controller.py is running on the board and the web UI is forwarded
(adb forward tcp:8090 tcp:8090). Hold a pose, then run this to measure the
tilt range for that pose.

Usage:  python3 calib_capture.py <label> <seconds>
Example: python3 calib_capture.py forward 4
"""
import json
import sys
import time
import urllib.request

label = sys.argv[1] if len(sys.argv) > 1 else "window"
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 3.0
URL = "http://localhost:8090/events"

pitch, roll, gy, gx = [], [], [], []
req = urllib.request.urlopen(URL, timeout=dur + 5)
start = time.monotonic()
while time.monotonic() - start < dur:
    line = req.readline()
    if not line:
        break
    if line.startswith(b"data: "):
        try:
            s = json.loads(line[6:])
        except ValueError:
            continue
        pitch.append(s["pitch"]); roll.append(s["roll"])
        gy.append(s["gy"]); gx.append(s["gx"])


def stats(a):
    if not a:
        return {}
    n = len(a)
    mean = sum(a) / n
    var = sum((x - mean) ** 2 for x in a) / n
    return {"n": n, "min": round(min(a), 2), "max": round(max(a), 2),
            "mean": round(mean, 2), "std": round(var ** 0.5, 2),
            "absmax": round(max(abs(min(a)), abs(max(a))), 2)}


print(json.dumps({
    "label": label,
    "pitch": stats(pitch),
    "roll": stats(roll),
    "gy_flick_peak": round(max((abs(v) for v in gy), default=0), 1),
    "gx_flick_peak": round(max((abs(v) for v in gx), default=0), 1),
}, indent=2))
