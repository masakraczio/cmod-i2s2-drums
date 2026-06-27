// Teensy 4.1 MIDI DIN input diagnostic.
// Test wiring: MIDI DIN -> optocoupler -> Teensy pin 0 / RX1.
// USB Serial prints raw MIDI bytes and parsed Note On/Off messages.

#include <Arduino.h>

static constexpr int MIDI_RX_PIN = 0;
static constexpr int LED_PIN = LED_BUILTIN;

HardwareSerial &MidiSerial = Serial1;

uint8_t runningStatus = 0;
uint8_t data1 = 0;
bool haveData1 = false;
uint32_t ledOffAtMs = 0;
uint32_t lastHeartbeatMs = 0;
uint32_t byteCount = 0;
uint32_t edgeCount = 0;
int lastRxLevel = -1;

void ledOn() {
  digitalWrite(LED_PIN, HIGH);
}

void ledOff() {
  digitalWrite(LED_PIN, LOW);
}

void pulseLed() {
  ledOn();
  ledOffAtMs = millis() + 40;
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
  pulseLed();

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
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  ledOff();
  pinMode(MIDI_RX_PIN, INPUT_PULLUP);

  Serial.begin(115200);
  delay(800);

  Serial.println();
  Serial.println("Teensy 4.1 MIDI DIN input test");
  Serial.print("MIDI RX: Serial1 pin ");
  Serial.println(MIDI_RX_PIN);
  Serial.print("LED pin: ");
  Serial.println(LED_PIN);
  Serial.println("Play notes on the MIDI controller. Waiting for bytes...");

  MidiSerial.begin(31250);
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
    Serial.print(" rx1_pin0=");
    Serial.println(rxLevel);
  }
}
