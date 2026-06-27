// ESP32-C3 SuperMini MIDI DIN bridge for the Cmod A7 drum computer.
// MIDI DIN IN -> ESP32 GPIO20 at 31250 baud.
// ESP32 GPIO21 -> Cmod A7 uart_rx at 115200 baud.

#include <Arduino.h>

static constexpr int MIDI_RX_PIN = 20;
static constexpr int CMOD_TX_PIN = 21;

HardwareSerial MidiSerial(1);
HardwareSerial CmodSerial(0);

char noteToDrumKey(uint8_t note) {
  switch (note) {
    case 35:
    case 36:
      return '1';  // kick
    case 38:
    case 40:
      return '2';  // snare
    case 42:
    case 44:
      return '3';  // closed hihat
    case 46:
      return '4';  // open hihat
    case 39:
      return '5';  // clap
    case 45:
    case 47:
      return '6';  // low tom
    case 48:
    case 50:
      return '7';  // high tom
    case 49:
    case 57:
      return '8';  // crash
    default:
      if (note >= 36 && note <= 43) {
        return char('1' + (note - 36));
      }
      return 0;
  }
}

void setup() {
  MidiSerial.begin(31250, SERIAL_8N1, MIDI_RX_PIN, -1);
  CmodSerial.begin(115200, SERIAL_8N1, -1, CMOD_TX_PIN);
}

void loop() {
  static uint8_t runningStatus = 0;
  static uint8_t data1 = 0;
  static bool haveData1 = false;

  while (MidiSerial.available() > 0) {
    const uint8_t b = MidiSerial.read();

    if (b & 0x80) {
      if (b < 0xF0) {
        runningStatus = b;
        haveData1 = false;
      }
      continue;
    }

    if (runningStatus == 0) {
      continue;
    }

    if (!haveData1) {
      data1 = b;
      haveData1 = true;
      continue;
    }

    const uint8_t data2 = b;
    haveData1 = false;

    const uint8_t command = runningStatus & 0xF0;
    if (command == 0x90 && data2 > 0) {
      const char key = noteToDrumKey(data1);
      if (key != 0) {
        CmodSerial.write(key);
      }
    }
  }
}
