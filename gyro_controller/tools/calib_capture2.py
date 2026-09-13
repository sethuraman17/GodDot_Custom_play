#!/usr/bin/env python3
"""Like calib_capture.py, but also reports raw accel (ax/ay/az) stats.

The az sign matters: the stock roll formula atan2(ay, hypot(ax,az)) folds at
+/-90 deg, so a pose past vertical reads as a smaller angle with az < 0.
An unfolded roll (full +/-180) is also computed here as atan2(ay, az).

Usage:  python3 calib_capture2.py <label> <seconds>
"""
import json
import math
import sys
import time
import urllib.request

label = sys.argv[1] if len(sys.argv) > 1 else "window"
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 3.0
URL = "http://localhost:8090/events"

series = {k: [] for k in ("pitch", "roll", "ax", "ay", "az", "gy", "gx")}
unfolded = []
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
        for k in series:
            series[k].append(s[k])
        unfolded.append(math.degrees(math.atan2(s["ay"], s["az"])))


def stats(a):
    if not a:
        return {}
    n = len(a)
    mean = sum(a) / n
    var = sum((x - mean) ** 2 for x in a) / n
    return {"n": n, "min": round(min(a), 2), "max": round(max(a), 2),
            "mean": round(mean, 2), "std": round(var ** 0.5, 2)}


print(json.dumps({
    "label": label,
    "pitch": stats(series["pitch"]),
    "roll_folded": stats(series["roll"]),
    "roll_unfolded": stats(unfolded),
    "ax": stats(series["ax"]),
    "ay": stats(series["ay"]),
    "az": stats(series["az"]),
    "gy_flick_peak": round(max((abs(v) for v in series["gy"]), default=0), 1),
    "gx_flick_peak": round(max((abs(v) for v in series["gx"]), default=0), 1),
}, indent=2))
