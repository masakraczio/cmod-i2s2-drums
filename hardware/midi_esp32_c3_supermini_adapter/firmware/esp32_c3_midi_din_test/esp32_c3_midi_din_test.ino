// ESP32-C3 SuperMini MIDI DIN input diagnostic.
// Test wiring: MIDI DIN -> 4N36/6N138/H11L1 -> ESP32 GPIO20.
// USB Serial prints raw MIDI bytes and parsed Note On/Off messages.

#include <Arduino.h>

static constexpr int MIDI_RX_PIN = 20;

#ifndef LED_BUILTIN
static constexpr int LED_PIN = 8;
#else
static constexpr int LED_PIN = LED_BUILTIN;
#endif

// If you see no MIDI bytes with a transistor optocoupler, try changing this to true.
static constexpr bool MIDI_RX_INVERTED = false;
static constexpr bool LED_ACTIVE_LOW = true;

HardwareSerial MidiSerial(1);

uint8_t runningStatus = 0;
uint8_t data1 = 0;
bool haveData1 = false;
uint32_t ledOffAtMs = 0;
uint32_t lastHeartbeatMs = 0;
uint32_t byteCount = 0;
uint32_t edgeCount = 0;
int lastRxLevel = -1;

void ledOn() {
  digitalWrite(LED_PIN, LED_ACTIVE_LOW ? LOW : HIGH);
}

void ledOff() {
  digitalWrite(LED_PIN, LED_ACTIVE_LOW ? HIGH : LOW);
}

void pulseLed() {
  ledOn();
  ledOffAtMs = millis() + 70;
}

void printHexByte(uint8_t value) {
  if (value < 0x10) {
    Serial.print('0');
  }
  Serial.print(value, HEX);
}

void printMidiMessage(uint8_t status, uint8_t note, uint8_t velocity) {
  const uint8_t command = status & 0xF0;
  const uint8_t channel = (status & 0x0F) + 1;

  if (command == 0x90 && velocity > 0) {
    Serial.print("NOTE ON   ch=");
  } else if (command == 0x80 || (command == 0x90 && velocity == 0)) {
    Serial.print("NOTE OFF  ch=");
  } else {
    Serial.print("MIDI MSG  ch=");
  }

  Serial.print(channel);
  Serial.print(" note=");
  Serial.print(note);
  Serial.print(" velocity=");
  Serial.println(velocity);
}

void handleMidiByte(uint8_t b) {
  byteCount++;

  Serial.print("RAW 0x");
  printHexByte(b);
  Serial.print("  count=");
  Serial.println(byteCount);

  if (b & 0x80) {
    if (b < 0xF0) {
      runningStatus = b;
      haveData1 = false;
    }
    return;
  }

  if (runningStatus == 0) {
    Serial.println("DATA BYTE IGNORED: no running status yet");
    return;
  }

  if (!haveData1) {
    data1 = b;
    haveData1 = true;
    return;
  }

  const uint8_t data2 = b;
  haveData1 = false;

  const uint8_t command = runningStatus & 0xF0;
  if (command == 0x80 || command == 0x90 || command == 0xA0 || command == 0xB0 || command == 0xE0) {
    printMidiMessage(runningStatus, data1, data2);
    if (command == 0x90 && data2 > 0) {
      pulseLed();
    }
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  ledOff();
  pinMode(MIDI_RX_PIN, INPUT);

  Serial.begin(115200);
  delay(800);

  Serial.println();
  Serial.println("ESP32-C3 SuperMini MIDI DIN input test");
  Serial.print("MIDI RX pin: GPIO");
  Serial.println(MIDI_RX_PIN);
  Serial.print("LED pin: GPIO");
  Serial.println(LED_PIN);
  Serial.print("LED active-low: ");
  Serial.println(LED_ACTIVE_LOW ? "yes" : "no");
  Serial.print("UART RX inverted: ");
  Serial.println(MIDI_RX_INVERTED ? "yes" : "no");
  Serial.println("Play notes on the MIDI controller. Waiting for bytes...");

  MidiSerial.begin(31250, SERIAL_8N1, MIDI_RX_PIN, -1, MIDI_RX_INVERTED);
  MidiSerial.setRxFIFOFull(1);
}

void loop() {
  while (MidiSerial.available() > 0) {
    handleMidiByte(uint8_t(MidiSerial.read()));
  }

  const int rxLevel = digitalRead(MIDI_RX_PIN);
  if (lastRxLevel < 0) {
    lastRxLevel = rxLevel;
  } else if (rxLevel != lastRxLevel) {
    lastRxLevel = rxLevel;
    edgeCount++;
  }

  if (ledOffAtMs != 0 && millis() >= ledOffAtMs) {
    ledOff();
    ledOffAtMs = 0;
  }

  if (millis() - lastHeartbeatMs > 2500) {
    lastHeartbeatMs = millis();
    Serial.print("waiting... bytes=");
    Serial.print(byteCount);
    Serial.print(" edges=");
    Serial.print(edgeCount);
    Serial.print(" gpio20=");
    Serial.println(rxLevel);
  }
}
