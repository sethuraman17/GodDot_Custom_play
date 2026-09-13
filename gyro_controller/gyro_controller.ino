// SPDX-License-Identifier: MPL-2.0
//
// Gyro/Tilt HID game controller for the Arduino UNO Q + Modulinos.
//
// This sketch runs on the MCU. It reads the Modulino Movement (IMU),
// Buttons, and Knob over Qwiic/I2C and streams the RAW values to the Linux
// side via RouterBridge. All of the WASD / threshold / mapping logic lives in
// controller.py so it can be tuned live (from the web dashboard) WITHOUT
// reflashing the microcontroller.
//
// Feedback comes back the other way: controller.py RPC-calls gc_move with
// the resolved movement direction and gc_event with game events (worm hit,
// water pickup, sun exposure, death), and this sketch answers with buzzer
// tone sequences and icons on the UNO Q's onboard 13x8 LED matrix
// (monochrome -- meaning is carried by shape and blinking, not color).
//
// The Buzzer is also driven locally on button presses so they get instant
// feedback with no round-trip latency.

#include "Arduino_RouterBridge.h"
#include "Arduino_LED_Matrix.h"
#include <Arduino_Modulino.h>

ModulinoMovement movement;
ModulinoButtons  buttons;
ModulinoKnob     knob;
ModulinoBuzzer   buzzer;
Arduino_LED_Matrix matrix;

bool hasMovement = false;
bool hasButtons  = false;
bool hasKnob     = false;
bool hasBuzzer   = false;

unsigned long lastSend = 0;
const unsigned long SEND_INTERVAL_MS = 20;  // ~50 Hz

bool prevA = false, prevB = false, prevC = false;

// ---------------------------------------------------------------------------
// Feedback state (written by the bridge RPC thread, consumed in loop()).
// ---------------------------------------------------------------------------
enum GameEvent { EV_NONE = 0, EV_WORM, EV_WATER, EV_LOW, EV_SUN, EV_SHADE, EV_DIED };

volatile int  pendingEvent = EV_NONE;
volatile int  moveFb = 0, moveLr = 0;   // -1/0/+1 from controller.py
volatile bool inSun = false;            // persistent sun-exposure state

// ---------------------------------------------------------------------------
// LED matrix icons: 8 rows x 13 cols, one uint16_t per row, bit 12 = col 0.
// ---------------------------------------------------------------------------
const uint16_t ICON_UP[8] = {
  0b0000001000000,
  0b0000011100000,
  0b0000111110000,
  0b0000001000000,
  0b0000001000000,
  0b0000001000000,
  0b0000001000000,
  0b0000000000000,
};
const uint16_t ICON_DOWN[8] = {
  0b0000000000000,
  0b0000001000000,
  0b0000001000000,
  0b0000001000000,
  0b0000001000000,
  0b0000111110000,
  0b0000011100000,
  0b0000001000000,
};
const uint16_t ICON_LEFT[8] = {
  0b0000000000000,
  0b0000100000000,
  0b0001000000000,
  0b0011111111100,
  0b0001000000000,
  0b0000100000000,
  0b0000000000000,
  0b0000000000000,
};
const uint16_t ICON_RIGHT[8] = {
  0b0000000000000,
  0b0000000010000,
  0b0000000001000,
  0b0011111111100,
  0b0000000001000,
  0b0000000010000,
  0b0000000000000,
  0b0000000000000,
};
const uint16_t ICON_WORM_X[8] = {   // harsh X = took worm damage
  0b0001000000100,
  0b0000100001000,
  0b0000010010000,
  0b0000001100000,
  0b0000001100000,
  0b0000010010000,
  0b0000100001000,
  0b0001000000100,
};
const uint16_t ICON_DROP[8] = {     // water drop = picked up water
  0b0000001000000,
  0b0000011100000,
  0b0000110110000,
  0b0001100011000,
  0b0001100011000,
  0b0001100011000,
  0b0000111110000,
  0b0000000000000,
};
const uint16_t ICON_BANG[8] = {     // exclamation = water running low
  0b0000001000000,
  0b0000001000000,
  0b0000001000000,
  0b0000001000000,
  0b0000001000000,
  0b0000000000000,
  0b0000001000000,
  0b0000000000000,
};
const uint16_t ICON_SUN[8] = {      // sun = taking sun damage
  0b0000001000000,
  0b0001000001000,
  0b0000011100000,
  0b1100111110011,
  0b1100111110011,
  0b0000011100000,
  0b0001000001000,
  0b0000001000000,
};
const uint16_t ICON_DEAD[8] = {     // frown = collapsed from heat
  0b0000000000000,
  0b0001100011000,
  0b0001100011000,
  0b0000000000000,
  0b0000000000000,
  0b0000011100000,
  0b0001100011000,
  0b0000000000000,
};
const uint16_t ICON_IDLE[8] = {     // small heartbeat dot
  0b0000000000000,
  0b0000000000000,
  0b0000000000000,
  0b0000001000000,
  0b0000001000000,
  0b0000000000000,
  0b0000000000000,
  0b0000000000000,
};

uint8_t frameBuf[8][13];
int lastFrameId = -1;

void showRows(const uint16_t rows[8], int frameId) {
  if (frameId == lastFrameId) return;   // avoid pointless rewrites
  lastFrameId = frameId;
  for (int r = 0; r < 8; r++)
    for (int c = 0; c < 13; c++)
      frameBuf[r][c] = (rows[r] >> (12 - c)) & 1;
  matrix.renderBitmap(frameBuf, 8, 13);
}

void showBlank(int frameId) {
  static const uint16_t blank[8] = {0, 0, 0, 0, 0, 0, 0, 0};
  showRows(blank, frameId);
}

// ---------------------------------------------------------------------------
// Buzzer tone sequences (non-blocking; stepped from loop()).
// ---------------------------------------------------------------------------
struct ToneStep { uint16_t freq; uint16_t ms; };  // freq 0 = rest

ToneStep toneSeq[3];
int toneCount = 0, toneIdx = 0;
unsigned long toneNextAt = 0;

void playSeq(uint16_t f1, uint16_t d1, uint16_t f2, uint16_t d2,
             uint16_t f3 = 0, uint16_t d3 = 0) {
  toneSeq[0] = {f1, d1};
  toneSeq[1] = {f2, d2};
  toneSeq[2] = {f3, d3};
  toneCount = d3 > 0 ? 3 : 2;
  toneIdx = 0;
  toneNextAt = millis();
}

void stepTones() {
  if (toneIdx >= toneCount || millis() < toneNextAt) return;
  ToneStep &s = toneSeq[toneIdx];
  if (s.freq > 0 && hasBuzzer) buzzer.tone(s.freq, s.ms);
  toneNextAt = millis() + s.ms + 20;
  toneIdx++;
}

// ---------------------------------------------------------------------------
// Event icon scheduling
// ---------------------------------------------------------------------------
int activeIcon = EV_NONE;
unsigned long iconUntil = 0;

void startEvent(int ev) {
  activeIcon = ev;
  switch (ev) {
    case EV_WORM:  iconUntil = millis() + 900;  playSeq(180, 150, 140, 200); break;
    case EV_WATER: iconUntil = millis() + 700;  playSeq(880, 70, 1320, 90);  break;
    case EV_LOW:   iconUntil = millis() + 1000; playSeq(520, 80, 0, 60, 520, 80); break;
    case EV_SUN:   iconUntil = millis() + 800;  playSeq(620, 90, 430, 140);  break;
    case EV_SHADE: iconUntil = millis() + 600;  playSeq(480, 70, 720, 110);  break;
    case EV_DIED:  iconUntil = millis() + 1500; playSeq(220, 500, 150, 400); break;
    default: break;
  }
}

void updateMatrix() {
  unsigned long now = millis();

  if (now < iconUntil) {
    bool blinkOn = (now / 180) % 2 == 0;   // events blink for urgency
    switch (activeIcon) {
      case EV_WORM:  if (blinkOn) showRows(ICON_WORM_X, 10); else showBlank(11); break;
      case EV_WATER: showRows(ICON_DROP, 12); break;           // steady = good news
      case EV_LOW:   if (blinkOn) showRows(ICON_BANG, 13); else showBlank(14); break;
      case EV_SUN:   if (blinkOn) showRows(ICON_SUN, 15); else showBlank(16); break;
      case EV_SHADE: showRows(ICON_DROP, 17); break;
      case EV_DIED:  showRows(ICON_DEAD, 18); break;
      default: break;
    }
    return;
  }

  // Persistent sun-exposure warning: slow sun blink while taking damage.
  if (inSun) {
    bool on = (now / 450) % 2 == 0;
    if (on) showRows(ICON_SUN, 20); else showBlank(21);
    return;
  }

  // Otherwise mirror movement. Turn feedback (left/right) wins over fwd/back.
  if (moveLr > 0)      showRows(ICON_RIGHT, 1);
  else if (moveLr < 0) showRows(ICON_LEFT, 2);
  else if (moveFb > 0) showRows(ICON_UP, 3);
  else if (moveFb < 0) showRows(ICON_DOWN, 4);
  else                 showRows(ICON_IDLE, 5);
}

// ---------------------------------------------------------------------------

void beep(unsigned int freq, unsigned int ms) {
  if (hasBuzzer) {
    buzzer.tone(freq, ms);
  }
}

void setup() {
  Bridge.begin();
  Modulino.begin();
  matrix.begin();

  // begin() returns true when the module is detected on the Qwiic bus.
  hasMovement = movement.begin();
  hasButtons  = buttons.begin();
  hasKnob     = knob.begin();
  hasBuzzer   = buzzer.begin();

  // Feedback RPCs, called by controller.py on the Linux side.
  Bridge.provide("gc_event", [](MsgPack::str_t ev) -> bool {
    if      (ev == "worm")  pendingEvent = EV_WORM;
    else if (ev == "water") pendingEvent = EV_WATER;
    else if (ev == "low")   pendingEvent = EV_LOW;
    else if (ev == "sun")   { pendingEvent = EV_SUN;   inSun = true;  }
    else if (ev == "shade") { pendingEvent = EV_SHADE; inSun = false; }
    else if (ev == "died")  { pendingEvent = EV_DIED;  inSun = false; }
    return true;
  });
  Bridge.provide("gc_move", [](MsgPack::str_t mv) -> bool {
    int fb = 0, lr = 0;
    if (sscanf(mv.c_str(), "%d,%d", &fb, &lr) == 2) {
      moveFb = fb;
      moveLr = lr;
    }
    return true;
  });

  // Startup chirp so we know the MCU booted and the buzzer is alive.
  if (hasBuzzer) {
    buzzer.tone(880, 90);
  }
}

void loop() {
  stepTones();

  int ev = pendingEvent;
  if (ev != EV_NONE) {
    pendingEvent = EV_NONE;
    startEvent(ev);
  }
  updateMatrix();

  unsigned long now = millis();
  if (now - lastSend < SEND_INTERVAL_MS) {
    return;
  }
  lastSend = now;

  // ---- Movement (IMU): accel in g, gyro in deg/s -----------------------
  float ax = 0, ay = 0, az = 0;   // accelerometer  (tilt)
  float gx = 0, gy = 0, gz = 0;   // gyroscope      (rotation rate)
  if (hasMovement) {
    movement.update();
    ax = movement.getX();
    ay = movement.getY();
    az = movement.getZ();
    // NOTE: on ModulinoMovement getRoll/Pitch/Yaw are the raw gyro axes (dps).
    gx = movement.getRoll();
    gy = movement.getPitch();
    gz = movement.getYaw();
  }

  // ---- Buttons (A/B/C) --------------------------------------------------
  int bA = 0, bB = 0, bC = 0;
  if (hasButtons) {
    buttons.update();
    bA = (buttons.isPressed(0) == HIGH) ? 1 : 0;
    bB = (buttons.isPressed(1) == HIGH) ? 1 : 0;
    bC = (buttons.isPressed(2) == HIGH) ? 1 : 0;

    // Local low-latency feedback on a fresh press.
    if (bA && !prevA) beep(1200, 40);   // jump
    if (bB && !prevB) beep(700, 40);    // sprint
    if (bC && !prevC) beep(950, 40);    // interact
    prevA = bA; prevB = bB; prevC = bC;

    // Light the button LEDs to mirror state (nice for demos).
    buttons.setLeds(bA, bB, bC);
  }

  // ---- Knob (rotary encoder + push) ------------------------------------
  int kpos = 0, kp = 0;
  if (hasKnob) {
    kpos = knob.get();                 // absolute position; Linux diffs it
    kp   = knob.isPressed() ? 1 : 0;
  }

  // Compact CSV payload. Linux parses this and applies all mapping logic:
  //   ax,ay,az,gx,gy,gz,bA,bB,bC,kpos,kp
  String payload =
      String(ax, 3) + "," + String(ay, 3) + "," + String(az, 3) + "," +
      String(gx, 2) + "," + String(gy, 2) + "," + String(gz, 2) + "," +
      String(bA) + "," + String(bB) + "," + String(bC) + "," +
      String(kpos) + "," + String(kp);

  Bridge.notify("modulino_controller", payload.c_str());
}
