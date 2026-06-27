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
  Serial.println("ESP32-C3 SuperMini blink test");
  Serial.print("LED pin: ");
  Serial.println(LED_PIN);
}

void loop() {
  digitalWrite(LED_PIN, HIGH);
  Serial.println("LED HIGH");
  delay(500);

  digitalWrite(LED_PIN, LOW);
  Serial.println("LED LOW");
  delay(500);
}
