// ESP32-C3 SuperMini standalone blink test.
// Most ESP32-C3 SuperMini boards have the onboard LED on GPIO8.

#include <Arduino.h>

#ifndef LED_BUILTIN
static constexpr int LED_PIN = 8;
#else
static constexpr int LED_PIN = LED_BUILTIN;
#endif

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(115200);
  delay(500);
  Serial.println("ESP32-C3 SuperMini accelerating/decelerating blink test");
  Serial.print("LED pin: ");
  Serial.println(LED_PIN);
}

void loop() {
  static constexpr int delaysMs[] = { 35, 45, 60, 80, 110, 150, 210, 300, 430, 600 };

  Serial.println("Pattern start: fast -> slow");
  for (int i = 0; i < int(sizeof(delaysMs) / sizeof(delaysMs[0])); i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(delaysMs[i]);
    digitalWrite(LED_PIN, LOW);
    delay(delaysMs[i]);
  }

  delay(350);
}
