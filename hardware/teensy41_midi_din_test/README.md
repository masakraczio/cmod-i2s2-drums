# Teensy 4.1 MIDI DIN Test

Standalone MIDI DIN input diagnostic for checking the optocoupler/DIN wiring without the Cmod A7 or ESP32-C3.

## Wiring

- MIDI DIN pin 4 -> 220R -> optocoupler input LED anode.
- MIDI DIN pin 5 -> optocoupler input LED cathode.
- MIDI DIN pin 2 -> shield/chassis only; do not connect it to Teensy GND for this isolated input test.
- Optocoupler output emitter -> Teensy GND.
- Optocoupler output collector -> Teensy pin 0 / RX1.
- Teensy 3.3V -> 1k to 4.7k pull-up -> Teensy pin 0 / RX1.

For a 4N36:

- pin 1 = input LED anode
- pin 2 = input LED cathode
- pin 4 = emitter -> Teensy GND
- pin 5 = collector -> Teensy pin 0 / RX1 and pull-up
- pin 6 = optional 47k to 220k to GND

## Build and upload

```powershell
& "C:\Program Files\Arduino CLI\arduino-cli.exe" compile --fqbn teensy:avr:teensy41 .\hardware\teensy41_midi_din_test\firmware\teensy41_midi_din_test
& "C:\Program Files\Arduino CLI\arduino-cli.exe" board list
& "C:\Program Files\Arduino CLI\arduino-cli.exe" upload -p <teensy-port-from-board-list> --fqbn teensy:avr:teensy41 .\hardware\teensy41_midi_din_test\firmware\teensy41_midi_din_test
```

Serial monitor is 115200 baud.

When the MIDI input is idle, `rx1_pin0` should normally read `1`. If it reads `0`, the optocoupler output is being held low.
