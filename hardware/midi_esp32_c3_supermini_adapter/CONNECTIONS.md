# Connections

## MIDI DIN Input

Use an opto-isolated MIDI input. Do not wire the DIN connector directly into the ESP32-C3.

Suggested 5-pin DIN input:

| DIN pin | Function | Adapter connection |
| --- | --- | --- |
| 4 | MIDI current source | Series resistor to 6N138 LED anode |
| 5 | MIDI current sink | 6N138 LED cathode path |
| 2 | Shield | Chassis/shield only; keep away from ESP32/Cmod logic ground |
| 1 | NC | Not connected |
| 3 | NC | Not connected |

Suggested opto side:

- DIN pin 4 -> `R1` 220 ohm -> 6N138 LED anode.
- DIN pin 5 -> reverse protection diode / LED cathode return.
- 6N138 logic side powered from ESP32-C3 `3V3`.
- 6N138 output -> ESP32-C3 `GPIO20` through `MIDI_RX`.
- Pull up 6N138 output to `3V3`, start with 2.2k to 4.7k.
- Add 100 nF decoupling near the 6N138.

## ESP32-C3 SuperMini

Recommended logical pins for firmware:

| ESP32-C3 pin | Direction | Function |
| --- | --- | --- |
| GPIO20 | input | MIDI UART RX, 31250 baud |
| GPIO21 | output | Cmod UART TX, 115200 baud |
| 3V3 | power | Optocoupler logic pull-up / decoupling |
| GND | ground | Common with Cmod A7 ground |
| 5V | power | Optional board power from USB or external 5 V, depending on your module |

SuperMini clone pinouts vary. Verify these labels against the board in your hand before PCB routing.

## Cmod A7 Header

Use the same UART input already used by the Web UI bridge.

| Adapter pin | Cmod A7 |
| --- | --- |
| ESP32 GPIO21 / UART TX | `uart_rx` FPGA input |
| GND | GND |
| 3V3 | optional only if you intentionally share 3.3 V power |
| ESP32 GPIO20 / UART RX | optional future return path from Cmod |

The first revision should power ESP32 from USB during bring-up. Share only GND and TX-to-uart_rx with Cmod until the signal path is verified.

## Bring-Up

1. Program the Cmod bitstream.
2. Load the drum sample bank.
3. Flash the ESP32-C3 firmware.
4. Open a serial monitor only on the ESP32 debug USB if needed.
5. Play MiniLab pads/keys through DIN MIDI OUT.
6. Verify that ESP32 sees Note On events and sends `1` to `8` to the Cmod.
