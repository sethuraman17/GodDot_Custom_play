#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""
Gyro/Tilt HID game controller -- Linux (Arduino UNO Q) side.

Pipeline:
    Modulinos --I2C--> MCU (gyro_controller.ino) --RouterBridge--> THIS SCRIPT
        --> USB-HID reports (/dev/hidg0 keyboard, /dev/hidg1 mouse) --> host PC

What it maps (tilt + gyro hybrid):
    * Tilt the board forward/back  -> W / S      (held while tilted)
    * Tilt the board left/right    -> A / D
    * Fast gyro "flick"            -> momentary W/A/S/D nudge (hybrid assist)
    * Button A                     -> Space  (jump)
    * Button B                     -> LeftShift (sprint, held)
    * Button C                     -> unused (reserved)
    * Knob rotate                  -> mouse scroll wheel (zoom in / out)

It also serves a self-contained web UI (no external packages needed):
    *  /            tuning dashboard + live input visualizer
    *  /events      Server-Sent-Events stream of live state
    *  /config      POST live tuning parameters
    *  /hid         POST master HID enable/disable switch
    *  /recenter    POST zero the tilt axes on the current pose

Run on the board:   python3 controller.py
Then on your host:  adb forward tcp:8090 tcp:8090   &&   open http://localhost:8090
"""

import json
import math
import os
import socket
import struct
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------
SOCKET_PATH = "/var/run/arduino-router.sock"
TOPIC = "modulino_controller"
HID_KB = "/dev/hidg0"      # 7-byte report: [modifiers, k1, k2, k3, k4, k5, k6]
HID_MOUSE = "/dev/hidg1"   # 4-byte report: [buttons, x, y, scroll]
HTTP_PORT = 8090

PEEK_LINGER = 0.35  # s: keep the peek key held past the last knob detent

# HID usage codes
KC = {"w": 0x1A, "a": 0x04, "s": 0x16, "d": 0x07,
      "space": 0x2C, "e": 0x08, "i": 0x0C, "r": 0x15,   # r -> game force field
      "peekl": 0x36, "peekr": 0x37,       # , and . -- game camera peek keys
      # Discrete knob-nav keys the game menu reads ([ ] \); one-frame taps so a
      # detent = a single menu step. Unbound during gameplay (harmless there).
      "menu_prev": 0x2F, "menu_next": 0x30, "menu_select": 0x31}
MOD_LSHIFT = 0x02

# Live-tunable parameters (mirrored/edited from the web dashboard).
CONFIG = {
    "tilt_on": 22.0,       # deg: start pressing a direction past this tilt
    "tilt_off": 13.0,      # deg: release once tilt falls back under this (hysteresis)
    "gyro_flick": 120.0,   # dps: rotation rate that triggers a momentary flick
    "flick_hold_ms": 120,  # how long a flick keeps the key down
    "invert_fb": False,    # flip forward/back
    "invert_lr": False,    # flip left/right
    "swap_axes": True,     # swap which physical axis is FB vs LR
    "pitch_offset": -1.1,  # deg: neutral-pose pitch (subtracted; POST /recenter)
    "roll_offset": 84.7,   # deg: neutral-pose roll  (subtracted; POST /recenter)
    "knob_mode": "peek",   # "peek" = hold ,/. camera-peek keys, "scroll" = wheel zoom
    "scroll_step": 1,      # mouse-scroll ticks per knob detent (scroll mode)
    "invert_scroll": False,
    "sprint_full": 45.0,   # deg: tilt depth (past tilt_on) that means full sprint
    "enabled": False,      # HID master switch (start OFF for safe calibration)
}
# Defaults above were calibrated 2026-07-04 for the current sensor mounting:
# neutral rests at roll ~ +85 deg (sensor on its side), forward/back swings
# roll +/-50 deg (=> swap_axes), left/right swings pitch +/-50 deg.

STATE = {
    "connected": False,
    "ax": 0.0, "ay": 0.0, "az": 0.0,
    "gx": 0.0, "gy": 0.0, "gz": 0.0,
    "pitch": 0.0, "roll": 0.0,
    "fb": 0, "lr": 0,           # -1/0/+1 resolved direction
    "keys": [],                 # active key names for the visualizer
    "sprint": 0.0,              # analog sprint factor 0..1 (tilt depth)
    "jump": False,
    "scroll": 0,                # last scroll tick sign
    "kpos": 0, "kpressed": False,
    "btnA": False, "btnB": False, "btnC": False,
    "hid_ok": True,
}

LOCK = threading.Lock()

# Game events the /event endpoint accepts and relays to the MCU for buzzer +
# LED-matrix feedback (see gyro_controller.ino).
GAME_EVENTS = ("worm", "water", "low", "sun", "shade", "died")

# Router socket for Linux -> MCU sends (owned by reader_loop, used by the
# HTTP thread and the mapper; sends are serialized by SEND_LOCK).
MCU_LINK = {"sock": None}
SEND_LOCK = threading.Lock()
_MSGID = [100]


def send_to_mcu(method, payload):
    """RPC-request `method(payload)` on the MCU via the router. Best-effort:
    returns False if the bridge is down; the MCU replies are ignored."""
    with LOCK:
        sock = MCU_LINK["sock"]
    if sock is None:
        return False
    with SEND_LOCK:
        _MSGID[0] += 1
        frame = mp_encode([0, _MSGID[0], method, [payload]])
        try:
            sock.sendall(frame)
            return True
        except OSError as e:
            log("mcu send failed:", e)
            return False


def log(*a):
    print("[controller]", *a, file=sys.stderr, flush=True)


# ==========================================================================
# Minimal msgpack (encode subset + streaming decoder). No external deps.
# ==========================================================================
class _Incomplete(Exception):
    pass


def mp_encode(obj):
    if obj is None:
        return b"\xc0"
    if isinstance(obj, bool):
        return b"\xc3" if obj else b"\xc2"
    if isinstance(obj, int):
        if 0 <= obj <= 0x7F:
            return bytes([obj])
        if -32 <= obj < 0:
            return bytes([obj & 0xFF])
        if 0 <= obj <= 0xFFFF:
            return b"\xcd" + struct.pack(">H", obj)
        if 0 <= obj <= 0xFFFFFFFF:
            return b"\xce" + struct.pack(">I", obj)
        return b"\xd3" + struct.pack(">q", obj)
    if isinstance(obj, str):
        b = obj.encode("utf-8")
        n = len(b)
        if n <= 0x1F:
            return bytes([0xA0 | n]) + b
        if n <= 0xFF:
            return b"\xd9" + bytes([n]) + b
        return b"\xda" + struct.pack(">H", n) + b
    if isinstance(obj, (list, tuple)):
        n = len(obj)
        if n <= 0x0F:
            head = bytes([0x90 | n])
        else:
            head = b"\xdc" + struct.pack(">H", n)
        return head + b"".join(mp_encode(x) for x in obj)
    raise TypeError("cannot encode %r" % (obj,))


def _need(buf, i, n):
    if i + n > len(buf):
        raise _Incomplete()


def mp_decode(buf, i):
    """Return (value, next_index) or raise _Incomplete if buf too short."""
    _need(buf, i, 1)
    c = buf[i]
    i += 1
    if c <= 0x7F:
        return c, i
    if c >= 0xE0:
        return c - 0x100, i
    if 0x80 <= c <= 0x8F:       # fixmap
        return _decode_map(buf, i, c & 0x0F)
    if 0x90 <= c <= 0x9F:       # fixarray
        return _decode_array(buf, i, c & 0x0F)
    if 0xA0 <= c <= 0xBF:       # fixstr
        return _decode_str(buf, i, c & 0x1F)
    if c == 0xC0:
        return None, i
    if c == 0xC2:
        return False, i
    if c == 0xC3:
        return True, i
    if c in (0xC4, 0xC5, 0xC6):  # bin 8/16/32
        sz = {0xC4: 1, 0xC5: 2, 0xC6: 4}[c]
        _need(buf, i, sz)
        n = int.from_bytes(buf[i:i + sz], "big"); i += sz
        _need(buf, i, n)
        return bytes(buf[i:i + n]), i + n
    if c == 0xCA:
        _need(buf, i, 4); return struct.unpack(">f", buf[i:i + 4])[0], i + 4
    if c == 0xCB:
        _need(buf, i, 8); return struct.unpack(">d", buf[i:i + 8])[0], i + 8
    if c in (0xCC, 0xCD, 0xCE, 0xCF):  # uint 8/16/32/64
        sz = {0xCC: 1, 0xCD: 2, 0xCE: 4, 0xCF: 8}[c]
        _need(buf, i, sz)
        return int.from_bytes(buf[i:i + sz], "big"), i + sz
    if c in (0xD0, 0xD1, 0xD2, 0xD3):  # int 8/16/32/64
        sz = {0xD0: 1, 0xD1: 2, 0xD2: 4, 0xD3: 8}[c]
        _need(buf, i, sz)
        return int.from_bytes(buf[i:i + sz], "big", signed=True), i + sz
    if c in (0xD9, 0xDA, 0xDB):  # str 8/16/32
        sz = {0xD9: 1, 0xDA: 2, 0xDB: 4}[c]
        _need(buf, i, sz)
        n = int.from_bytes(buf[i:i + sz], "big"); i += sz
        return _decode_str(buf, i, n)
    if c in (0xDC, 0xDD):        # array 16/32
        sz = 2 if c == 0xDC else 4
        _need(buf, i, sz)
        n = int.from_bytes(buf[i:i + sz], "big"); i += sz
        return _decode_array(buf, i, n)
    if c in (0xDE, 0xDF):        # map 16/32
        sz = 2 if c == 0xDE else 4
        _need(buf, i, sz)
        n = int.from_bytes(buf[i:i + sz], "big"); i += sz
        return _decode_map(buf, i, n)
    raise ValueError("bad msgpack byte 0x%02x" % c)


def _decode_str(buf, i, n):
    _need(buf, i, n)
    return buf[i:i + n].decode("utf-8", "replace"), i + n


def _decode_array(buf, i, n):
    out = []
    for _ in range(n):
        v, i = mp_decode(buf, i)
        out.append(v)
    return out, i


def _decode_map(buf, i, n):
    out = {}
    for _ in range(n):
        k, i = mp_decode(buf, i)
        v, i = mp_decode(buf, i)
        out[k] = v
    return out, i


# ==========================================================================
# HID output
# ==========================================================================
class Hid:
    def __init__(self):
        self.kb = None
        self.mouse = None
        self.cur_mod = 0
        self.cur_keys = ()

    def _kb(self):
        if self.kb is None:
            self.kb = open(HID_KB, "rb+", buffering=0)
        return self.kb

    def _ms(self):
        if self.mouse is None:
            self.mouse = open(HID_MOUSE, "rb+", buffering=0)
        return self.mouse

    def set_keys(self, mod, keycodes, enabled):
        """Send a keyboard report only when the pressed set changes."""
        keys = tuple(sorted(set(keycodes))[:6])
        if mod == self.cur_mod and keys == self.cur_keys:
            return True
        self.cur_mod, self.cur_keys = mod, keys
        if not enabled:
            return True
        report = bytes([mod] + list(keys) + [0] * (6 - len(keys)))
        try:
            self._kb().write(report)
            return True
        except Exception as e:  # noqa: BLE001
            log("hidg0 write failed:", e)
            self.kb = None
            return False

    def scroll(self, ticks, enabled):
        if not enabled or ticks == 0:
            return True
        s = max(-127, min(127, int(ticks))) & 0xFF
        try:
            self._ms().write(bytes([0, 0, 0, s]))
            return True
        except Exception as e:  # noqa: BLE001
            log("hidg1 write failed:", e)
            self.mouse = None
            return False

    def release_all(self):
        self.cur_mod, self.cur_keys = 0, ()
        try:
            self._kb().write(bytes(7))
        except Exception:  # noqa: BLE001
            pass


# ==========================================================================
# Mapping: raw sensor payload -> HID
# ==========================================================================
def tilt_dir(angle, prev, on, off):
    """Latching hysteresis: returns -1 / 0 / +1."""
    if prev > 0:
        return 1 if angle > off else 0
    if prev < 0:
        return -1 if angle < -off else 0
    if angle > on:
        return 1
    if angle < -on:
        return -1
    return 0


class Mapper:
    def __init__(self, hid):
        self.hid = hid
        self.fb_prev = 0
        self.lr_prev = 0
        self.fb_flick_until = 0.0
        self.fb_flick_sign = 0
        self.lr_flick_until = 0.0
        self.lr_flick_sign = 0
        self.last_kpos = None
        self.peek_dir = 0      # -1 left / +1 right, from the last knob detent
        self.peek_until = 0.0  # hold the peek key until this time
        self.last_move = None  # last "fb,lr" relayed to the MCU matrix
        self.pending_taps = [] # one-frame key taps (menu nav), drained each resolve
        self.prev_kp = 0       # knob-press level, for rising-edge detection

    def process(self, payload):
        parts = payload.split(",")
        if len(parts) < 11:
            return
        try:
            ax, ay, az = float(parts[0]), float(parts[1]), float(parts[2])
            gx, gy, gz = float(parts[3]), float(parts[4]), float(parts[5])
            bA, bB, bC = int(parts[6]), int(parts[7]), int(parts[8])
            kpos, kp = int(parts[9]), int(parts[10])
        except ValueError:
            return

        with LOCK:
            cfg = dict(CONFIG)

        # Tilt angles from the accelerometer (degrees).
        # Roll uses atan2(ay, az) for a full +/-180 range: the neutral grip
        # rests near +85 deg, and a forward tilt crosses vertical -- the
        # hypot form would fold there and read forward the same as back.
        pitch = math.degrees(math.atan2(ax, math.hypot(ay, az)))
        roll = math.degrees(math.atan2(ay, az))
        pitch -= cfg["pitch_offset"]
        roll -= cfg["roll_offset"]

        # Choose which physical axis drives forward/back vs left/right.
        if cfg["swap_axes"]:
            fb_angle, lr_angle = roll, pitch
            fb_rate, lr_rate = gx, gy
        else:
            fb_angle, lr_angle = pitch, roll
            fb_rate, lr_rate = gy, gx

        if cfg["invert_fb"]:
            fb_angle, fb_rate = -fb_angle, -fb_rate
        if cfg["invert_lr"]:
            lr_angle, lr_rate = -lr_angle, -lr_rate

        on, off = cfg["tilt_on"], cfg["tilt_off"]
        flick, hold = cfg["gyro_flick"], cfg["flick_hold_ms"] / 1000.0
        now = time.monotonic()

        # Tilt (with hysteresis latch).
        fb = tilt_dir(fb_angle, self.fb_prev, on, off)
        lr = tilt_dir(lr_angle, self.lr_prev, on, off)
        self.fb_prev, self.lr_prev = fb, lr

        # Gyro flick assist (hybrid): a fast rotation momentarily forces a dir.
        if abs(fb_rate) > flick:
            self.fb_flick_until = now + hold
            self.fb_flick_sign = 1 if fb_rate > 0 else -1
        if abs(lr_rate) > flick:
            self.lr_flick_until = now + hold
            self.lr_flick_sign = 1 if lr_rate > 0 else -1
        if now < self.fb_flick_until:
            fb = self.fb_flick_sign
        if now < self.lr_flick_until:
            lr = self.lr_flick_sign

        # Knob -> camera peek keys or scroll zoom, per knob_mode. Runs before
        # key resolution so a detent's peek key goes out in this same report.
        # Diff absolute position; ignore first sample.
        scroll_sign = 0
        scroll_fail = False
        if self.last_kpos is None:
            self.last_kpos = kpos
        else:
            kdelta = kpos - self.last_kpos
            if kdelta != 0:
                self.last_kpos = kpos
                sign = -1 if cfg["invert_scroll"] else 1
                # Menu navigation: one discrete step per detent, regardless of
                # knob_mode. The game only acts on these while the menu is open.
                self.pending_taps.append(
                    "menu_next" if kdelta * sign > 0 else "menu_prev")
                if cfg["knob_mode"] == "peek":
                    # Direction picks the peek side; keep the key held
                    # PEEK_LINGER past the last detent so discrete detents
                    # read as one continuous peek.
                    self.peek_dir = 1 if kdelta * sign > 0 else -1
                    self.peek_until = now + PEEK_LINGER
                    scroll_sign = self.peek_dir
                else:
                    ticks = kdelta * cfg["scroll_step"] * sign
                    scroll_sign = 1 if ticks > 0 else -1
                    if not self.hid.scroll(ticks, cfg["enabled"]):
                        scroll_fail = True

        # Resolve to keys.
        keys, names = [], []
        if fb > 0:
            keys.append(KC["w"]); names.append("w")
        elif fb < 0:
            keys.append(KC["s"]); names.append("s")
        if lr > 0:
            keys.append(KC["d"]); names.append("d")
        elif lr < 0:
            keys.append(KC["a"]); names.append("a")

        jump = bool(bA)
        force_field = bool(bB)  # Button B -> R -> deploy heat-wave force field
        interact = bool(bC)

        # Analog sprint: the deeper the tilt in the travel direction, the faster.
        # 0 at tilt_on, ramping to 1.0 at `sprint_full` degrees past neutral,
        # quantized to 10% steps. Only counts an axis actually moving the
        # character. Computed regardless of `enabled` (it is just a number the
        # game reads; movement can't happen without the WASD keys anyway), so
        # the dashboard SPRINT% and /speed stay usable for tuning while disarmed.
        mag = 0.0
        if fb != 0:
            mag = max(mag, abs(fb_angle))
        if lr != 0:
            mag = max(mag, abs(lr_angle))
        span = max(1.0, cfg["sprint_full"] - on)
        sprint_factor = 0.0
        if mag > on:
            sprint_factor = min(1.0, (mag - on) / span)
            sprint_factor = round(sprint_factor * 10) / 10.0
        if jump:
            keys.append(KC["space"]); names.append("space")
        if force_field:
            keys.append(KC["r"]); names.append("r")
        if interact:
            keys.append(KC["e"]); names.append("e")
        if kp:
            keys.append(KC["i"]); names.append("i")   # knob press -> inventory
        if kp and not self.prev_kp:                    # rising edge -> menu select
            self.pending_taps.append("menu_select")
        self.prev_kp = kp
        if cfg["knob_mode"] == "peek" and now < self.peek_until:
            pk = "peekr" if self.peek_dir > 0 else "peekl"
            keys.append(KC[pk]); names.append(pk)
        # Drain one-frame menu-nav taps: present this report, gone the next, so
        # the game sees a clean press/release (one menu step) per detent/click.
        for tap in self.pending_taps:
            keys.append(KC[tap]); names.append(tap)
        self.pending_taps = []
        # Sprint is analog (see /speed, read by the game); no Shift key is sent.
        mod = 0

        hid_ok = self.hid.set_keys(mod, keys, cfg["enabled"]) and not scroll_fail

        # Relay movement direction changes to the MCU LED matrix.
        move = "%d,%d" % (fb, lr)
        if move != self.last_move:
            self.last_move = move
            send_to_mcu("gc_move", move)

        with LOCK:
            STATE.update(
                ax=round(ax, 3), ay=round(ay, 3), az=round(az, 3),
                gx=round(gx, 1), gy=round(gy, 1), gz=round(gz, 1),
                pitch=round(pitch, 1), roll=round(roll, 1),
                fb=fb, lr=lr, keys=names, sprint=sprint_factor, jump=jump,
                scroll=scroll_sign, kpos=kpos, kpressed=bool(kp),
                btnA=bool(bA), btnB=bool(bB), btnC=bool(bC),
                hid_ok=hid_ok,
            )


# ==========================================================================
# RouterBridge reader thread
# ==========================================================================
def reader_loop(mapper):
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                client.connect(SOCKET_PATH)
                client.sendall(mp_encode([0, 1, "$/register", [TOPIC]]))
                with LOCK:
                    STATE["connected"] = True
                    MCU_LINK["sock"] = client
                log("connected to router, subscribed to", TOPIC)

                buf = bytearray()
                while True:
                    data = client.recv(4096)
                    if not data:
                        break
                    buf += data
                    i = 0
                    while i < len(buf):
                        try:
                            msg, ni = mp_decode(buf, i)
                        except _Incomplete:
                            break
                        i = ni
                        # Notification frame: [2, method, params]
                        if (isinstance(msg, list) and len(msg) >= 3
                                and msg[0] == 2 and msg[1] == TOPIC):
                            params = msg[2]
                            if params and isinstance(params[0], str):
                                mapper.process(params[0])
                    del buf[:i]
        except (FileNotFoundError, ConnectionRefusedError, OSError) as e:
            log("router connection issue:", e)
        with LOCK:
            STATE["connected"] = False
            MCU_LINK["sock"] = None
        mapper.hid.release_all()
        time.sleep(1.0)


# ==========================================================================
# Web UI (HTTP + SSE)
# ==========================================================================
INDEX_HTML = r"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>UNO Q Gyro Controller</title>
<style>
  :root{--bg:#0d1117;--panel:#161b22;--edge:#30363d;--txt:#e6edf3;
        --muted:#8b949e;--accent:#2f81f7;--on:#3fb950;--off:#f85149;--warn:#d29922}
  *{box-sizing:border-box}
  body{margin:0;font:14px/1.4 -apple-system,Segoe UI,Roboto,sans-serif;
       background:var(--bg);color:var(--txt);padding:18px}
  h1{font-size:18px;margin:0 0 4px}
  .sub{color:var(--muted);margin-bottom:16px}
  .grid{display:grid;gap:16px;grid-template-columns:repeat(auto-fit,minmax(300px,1fr))}
  .panel{background:var(--panel);border:1px solid var(--edge);border-radius:12px;padding:16px}
  .panel h2{font-size:13px;text-transform:uppercase;letter-spacing:.06em;
            color:var(--muted);margin:0 0 14px}
  .row{display:flex;justify-content:space-between;align-items:center;margin:8px 0}
  .pill{padding:3px 10px;border-radius:999px;font-weight:600;font-size:12px}
  .pill.on{background:rgba(63,185,80,.15);color:var(--on)}
  .pill.off{background:rgba(248,81,73,.15);color:var(--off)}
  /* master switch */
  .master{display:flex;align-items:center;gap:12px}
  .switch{position:relative;width:56px;height:30px;flex:none}
  .switch input{opacity:0;width:0;height:0}
  .slider{position:absolute;inset:0;background:#30363d;border-radius:30px;transition:.2s;cursor:pointer}
  .slider:before{content:"";position:absolute;height:22px;width:22px;left:4px;top:4px;
                 background:#fff;border-radius:50%;transition:.2s}
  input:checked+.slider{background:var(--off)}
  input:checked+.slider:before{transform:translateX(26px)}
  /* WASD pad */
  .pad{display:grid;grid-template-columns:repeat(3,54px);grid-template-rows:repeat(2,54px);
       gap:8px;justify-content:center;margin:6px auto 14px}
  .key{display:flex;align-items:center;justify-content:center;background:#21262d;
       border:1px solid var(--edge);border-radius:10px;font-weight:700;color:var(--muted);
       transition:.08s}
  .key.w{grid-column:2;grid-row:1}.key.a{grid-column:1;grid-row:2}
  .key.s{grid-column:2;grid-row:2}.key.d{grid-column:3;grid-row:2}
  .key.active{background:var(--accent);color:#fff;border-color:var(--accent);
              box-shadow:0 0 14px rgba(47,129,247,.6)}
  .lamps{display:flex;gap:10px;justify-content:center;flex-wrap:wrap}
  .lamp{padding:8px 12px;border-radius:8px;background:#21262d;border:1px solid var(--edge);
        color:var(--muted);font-weight:600;font-size:12px}
  .lamp.active{background:var(--on);color:#04250d;border-color:var(--on)}
  .lamp.warn.active{background:var(--warn);color:#241a02;border-color:var(--warn)}
  /* bars */
  .bar{position:relative;height:16px;background:#21262d;border-radius:8px;overflow:hidden;margin:4px 0}
  .bar>span{position:absolute;top:0;bottom:0;left:50%;background:var(--accent);width:0}
  .bar>i{position:absolute;left:50%;top:0;bottom:0;width:1px;background:var(--edge)}
  .lbl{display:flex;justify-content:space-between;font-size:12px;color:var(--muted)}
  .mono{font-variant-numeric:tabular-nums;color:var(--txt)}
  /* config */
  .cfg label{display:block;margin:12px 0 2px;font-size:12px;color:var(--muted)}
  .cfg input[type=range]{width:100%}
  .cfg .val{float:right;color:var(--txt);font-variant-numeric:tabular-nums}
  .checks{display:flex;flex-wrap:wrap;gap:14px;margin-top:12px}
  .checks label{display:flex;align-items:center;gap:6px;color:var(--txt);font-size:13px}
  .zoom{font-size:26px;text-align:center;margin-top:6px;color:var(--muted)}
  .zoom b{color:var(--accent)}
</style></head><body>
<h1>Arduino UNO Q &mdash; Gyro Game Controller</h1>
<div class="sub">Tilt &rarr; WASD (deeper = sprint) &nbsp;&middot;&nbsp; A Jump &middot; B Force field &middot; C Interact &nbsp;&middot;&nbsp; Knob peek/menu</div>

<div class="grid">
  <div class="panel">
    <h2>Status &amp; HID Output</h2>
    <div class="row"><span>Board link</span><span id="link" class="pill off">offline</span></div>
    <div class="row"><span>HID device</span><span id="hidok" class="pill on">ok</span></div>
    <div class="master" style="margin-top:14px">
      <label class="switch"><input type="checkbox" id="hidsw"><span class="slider"></span></label>
      <div><div style="font-weight:600" id="hidlbl">HID output OFF</div>
      <div style="color:var(--muted);font-size:12px">Turn on to send real keystrokes to this computer</div></div>
    </div>
  </div>

  <div class="panel">
    <h2>Input Visualizer</h2>
    <div class="pad">
      <div class="key w" id="k-w">W</div><div class="key a" id="k-a">A</div>
      <div class="key s" id="k-s">S</div><div class="key d" id="k-d">D</div>
    </div>
    <div class="lamps">
      <div class="lamp" id="l-jump">JUMP (Space)</div>
      <div class="lamp warn" id="l-sprint">SPRINT 0%</div>
    </div>
    <div class="zoom" id="zoom">zoom &nbsp;<b>&mdash;</b></div>
  </div>

  <div class="panel">
    <h2>Live Sensors</h2>
    <div class="lbl"><span>Roll (fwd/back)</span><span class="mono" id="v-roll">0&deg;</span></div>
    <div class="bar"><i></i><span id="b-roll"></span></div>
    <div class="lbl"><span>Pitch (left/right)</span><span class="mono" id="v-pitch">0&deg;</span></div>
    <div class="bar"><i></i><span id="b-pitch"></span></div>
    <button id="recenter" style="margin-top:10px;padding:6px 14px;cursor:pointer;
      background:#2a3f5f;color:#dbe6ff;border:1px solid #46648f;border-radius:6px">
      Recenter neutral (hold resting pose)</button>
    <div class="lbl" style="margin-top:10px"><span>Gyro dps (x / y / z)</span>
      <span class="mono" id="v-gyro">0 / 0 / 0</span></div>
    <div class="lbl" style="margin-top:6px"><span>Knob position</span>
      <span class="mono" id="v-knob">0</span></div>
    <div class="row"><span>Buttons A / B / C</span><span class="mono" id="v-btn">&mdash;</span></div>
  </div>

  <div class="panel cfg">
    <h2>Tuning</h2>
    <label>Tilt ON threshold <span class="val" id="o-tilt_on"></span></label>
    <input type="range" id="c-tilt_on" min="5" max="45" step="1">
    <label>Tilt OFF threshold (hysteresis) <span class="val" id="o-tilt_off"></span></label>
    <input type="range" id="c-tilt_off" min="0" max="40" step="1">
    <label>Gyro flick threshold (dps) <span class="val" id="o-gyro_flick"></span></label>
    <input type="range" id="c-gyro_flick" min="40" max="400" step="10">
    <label>Flick hold (ms) <span class="val" id="o-flick_hold_ms"></span></label>
    <input type="range" id="c-flick_hold_ms" min="40" max="400" step="10">
    <label>Scroll step per detent <span class="val" id="o-scroll_step"></span></label>
    <input type="range" id="c-scroll_step" min="1" max="10" step="1">
    <div class="checks">
      <label><input type="checkbox" id="c-invert_fb"> invert F/B</label>
      <label><input type="checkbox" id="c-invert_lr"> invert L/R</label>
      <label><input type="checkbox" id="c-swap_axes"> swap axes</label>
      <label><input type="checkbox" id="c-invert_scroll"> invert knob</label>
      <label><input type="checkbox" id="c-knobcam"> knob = camera peek</label>
    </div>
  </div>
</div>

<script>
const $=id=>document.getElementById(id);
const NUMS=["tilt_on","tilt_off","gyro_flick","flick_hold_ms","scroll_step"];
const BOOLS=["invert_fb","invert_lr","swap_axes","invert_scroll"];
let cfgReady=false;

function postCfg(patch){
  fetch("/config",{method:"POST",headers:{"Content-Type":"application/json"},
    body:JSON.stringify(patch)});
}
NUMS.forEach(k=>{const el=$("c-"+k);el.addEventListener("input",()=>{
  $("o-"+k).textContent=el.value; if(cfgReady) postCfg({[k]:Number(el.value)});});});
BOOLS.forEach(k=>{const el=$("c-"+k);el.addEventListener("change",()=>{
  if(cfgReady) postCfg({[k]:el.checked});});});

$("recenter").addEventListener("click",()=>{
  fetch("/recenter",{method:"POST"});
});

$("c-knobcam").addEventListener("change",()=>{
  if(cfgReady) postCfg({knob_mode:$("c-knobcam").checked?"peek":"scroll"});
});

$("hidsw").addEventListener("change",()=>{
  fetch("/hid",{method:"POST",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({enabled:$("hidsw").checked})});
});

function applyConfig(c){
  NUMS.forEach(k=>{$("c-"+k).value=c[k];$("o-"+k).textContent=c[k];});
  BOOLS.forEach(k=>{$("c-"+k).checked=!!c[k];});
  $("c-knobcam").checked=c.knob_mode==="peek";
  $("hidsw").checked=!!c.enabled;
  cfgReady=true;
}
fetch("/config").then(r=>r.json()).then(applyConfig);

function bar(el,val,max){
  const f=Math.max(-1,Math.min(1,val/max));
  el.style.width=Math.abs(f)*50+"%";
  el.style.left=f>=0?"50%":(50+f*50)+"%";
}
function setKey(name,on){$("k-"+name).classList.toggle("active",on);}

const es=new EventSource("/events");
es.onmessage=e=>{
  const s=JSON.parse(e.data);
  $("link").className="pill "+(s.connected?"on":"off");
  $("link").textContent=s.connected?"online":"offline";
  $("hidok").className="pill "+(s.hid_ok?"on":"off");
  $("hidok").textContent=s.hid_ok?"ok":"error";
  const en=!!s.enabled;
  $("hidlbl").textContent="HID output "+(en?"ON":"OFF");

  ["w","a","s","d"].forEach(k=>setKey(k,s.keys.includes(k)));
  $("l-jump").className="lamp"+(s.jump?" active":"");
  var sp=Math.round((s.sprint||0)*100);
  $("l-sprint").className="lamp warn"+(sp>0?" active":"");
  $("l-sprint").textContent="SPRINT "+sp+"%";
  $("zoom").innerHTML=s.scroll>0?'knob <b>&#9654;</b>':
                      s.scroll<0?'knob <b>&#9664;</b>':'knob &nbsp;<b>&mdash;</b>';

  $("v-pitch").innerHTML=s.pitch+"&deg;";
  $("v-roll").innerHTML=s.roll+"&deg;";
  bar($("b-pitch"),s.pitch,45); bar($("b-roll"),s.roll,45);
  $("v-gyro").textContent=s.gx+" / "+s.gy+" / "+s.gz;
  $("v-knob").textContent=s.kpos+(s.kpressed?"  (pressed)":"");
  $("v-btn").textContent=(s.btnA?"A ":"- ")+(s.btnB?"B ":"- ")+(s.btnC?"C":"-");
};
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass  # quiet

    def _send(self, code, body, ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/index"):
            self._send(200, INDEX_HTML.encode("utf-8"), "text/html; charset=utf-8")
        elif self.path == "/config":
            with LOCK:
                self._send(200, json.dumps(CONFIG).encode())
        elif self.path == "/speed":
            # Tiny hot path: the game polls this ~20 Hz for the analog sprint
            # factor (deeper tilt = faster) and the current armed state (so the
            # game can auto-disarm when its window loses focus). Low latency.
            with LOCK:
                factor = STATE["sprint"]
                en = CONFIG["enabled"]
            self._send(200, json.dumps({"sprint": factor, "enabled": en}).encode())
        elif self.path == "/events":
            self._sse()
        else:
            self._send(404, b'{"error":"not found"}')

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(n) if n else b"{}"
        try:
            data = json.loads(raw or b"{}")
        except ValueError:
            self._send(400, b'{"error":"bad json"}'); return

        if self.path == "/config":
            with LOCK:
                for k, v in data.items():
                    if k in CONFIG and k != "enabled":
                        CONFIG[k] = v
            self._send(200, b'{"ok":true}')
        elif self.path == "/hid":
            enabled = bool(data.get("enabled", False))
            with LOCK:
                CONFIG["enabled"] = enabled
            if not enabled:
                HID.release_all()
            log("HID output", "ENABLED" if enabled else "disabled")
            self._send(200, b'{"ok":true}')
        elif self.path == "/event":
            # Game -> board feedback (buzzer + LED matrix). Best-effort.
            event = str(data.get("event", ""))
            if event not in GAME_EVENTS:
                self._send(400, b'{"error":"unknown event"}')
                return
            sent = send_to_mcu("gc_event", event)
            self._send(200, json.dumps({"ok": True, "sent": sent}).encode())
        elif self.path == "/recenter":
            # Zero the tilt axes on the current pose. STATE holds the latest
            # offset-adjusted sample, so fold the residual into the offsets.
            with LOCK:
                CONFIG["pitch_offset"] = round(CONFIG["pitch_offset"] + STATE["pitch"], 1)
                CONFIG["roll_offset"] = round(CONFIG["roll_offset"] + STATE["roll"], 1)
                body = json.dumps({"ok": True,
                                   "pitch_offset": CONFIG["pitch_offset"],
                                   "roll_offset": CONFIG["roll_offset"]}).encode()
            log("recentered: pitch_offset=%s roll_offset=%s" %
                (CONFIG["pitch_offset"], CONFIG["roll_offset"]))
            self._send(200, body)
        else:
            self._send(404, b'{"error":"not found"}')

    def _sse(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        try:
            while True:
                with LOCK:
                    snap = dict(STATE)
                    snap["enabled"] = CONFIG["enabled"]
                self.wfile.write(b"data: " + json.dumps(snap).encode() + b"\n\n")
                self.wfile.flush()
                time.sleep(0.04)  # ~25 Hz
        except (BrokenPipeError, ConnectionResetError):
            pass


# global HID handle (used by the HTTP thread for release-all on disable)
HID = Hid()


def main():
    if not os.path.exists(SOCKET_PATH):
        log("WARNING: router socket not found at", SOCKET_PATH)

    mapper = Mapper(HID)
    threading.Thread(target=reader_loop, args=(mapper,), daemon=True).start()

    server = ThreadingHTTPServer(("0.0.0.0", HTTP_PORT), Handler)
    log("web UI on http://0.0.0.0:%d  (adb forward tcp:%d tcp:%d)"
        % (HTTP_PORT, HTTP_PORT, HTTP_PORT))
    log("HID output starts DISABLED - flip the switch in the UI when ready.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        HID.release_all()
        log("stopped, released all keys.")


if __name__ == "__main__":
    main()
