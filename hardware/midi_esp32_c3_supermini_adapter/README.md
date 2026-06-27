# MIDI DIN to Cmod A7 Adapter, ESP32-C3 SuperMini

Rev A starter project for a small adapter that translates DIN MIDI input into the existing Cmod A7 drum UART trigger protocol.

Signal path:

```text
MIDI DIN IN -> 6N138 optocoupler -> ESP32-C3 SuperMini UART RX
ESP32-C3 SuperMini UART TX -> Cmod A7 uart_rx
```

The ESP32-C3 runs the firmware in `firmware/esp32_c3_midi_bridge/` and sends ASCII drum keys `1` to `8` to the FPGA at 115200 baud. This matches the current FPGA/Web UI trigger protocol.

## Files

- `midi_esp32_c3_supermini_adapter.kicad_pro` - KiCad 10 project.
- `midi_esp32_c3_supermini_adapter.kicad_sch` - readable Rev A schematic with symbols and wiring.
- `midi_esp32_c3_supermini_adapter.kicad_pcb` - board outline placeholder for the adapter.
- `CONNECTIONS.md` - wiring, pin choices, and bring-up checks.
- `BOM.csv` - first-pass bill of materials.
- `firmware/esp32_c3_midi_bridge/esp32_c3_midi_bridge.ino` - Arduino sketch for ESP32-C3.

## Important

ESP32-C3 SuperMini boards are clone-family modules. Before ordering a PCB, compare the silkscreen and pinout of your exact board against the pin choices in `CONNECTIONS.md`.

The recommended logical pins are:

- MIDI input to ESP32-C3: `GPIO20`, UART RX, 31250 baud.
- Cmod trigger output from ESP32-C3: `GPIO21`, UART TX, 115200 baud.
- Common ground between ESP32-C3 and Cmod A7.
- Do not connect MIDI DIN pin 2 to ESP32/Cmod signal ground on the isolated MIDI input side.

## Open In KiCad

Open:

```powershell
F:\CMODA7\pmod_i2s2_drums\hardware\midi_esp32_c3_supermini_adapter\midi_esp32_c3_supermini_adapter.kicad_pro
```

KiCad 10.0.3 was used locally.
