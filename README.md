# Cmod A7 Pmod I2S2 Drum Computer

FPGA drum computer prototype for the Digilent Cmod A7-35T with Pmod I2S2 stereo audio output.

## Contents

- `src/` - SystemVerilog RTL for the drum engine, I2S top level, PSRAM/SRAM experiments, and support blocks.
- `constrs/` - Cmod A7 pin constraints.
- `src/rtl/generated/` - generated drum sample ROM data used by the current RTL.
- `drum_pad.ps1` and `drum_sequencer_ui.ps1` - Windows helper UI scripts.
- `webui/` - browser UI served by a local PowerShell HTTP-to-serial bridge.
- `hardware/` - companion hardware projects, including the ESP32-C3 SuperMini MIDI DIN bridge adapter.
- `artifacts/` - curated bitstream and implementation reports from the latest available build.

## Target

- Board: Digilent Cmod A7-35T
- FPGA: `xc7a35tcpg236-1`
- Audio: Digilent Pmod I2S2
- Top module: `cmod_i2s2_drums`
- Vivado project: `pmod_i2s2_drums.xpr`

## Build

The project was last built with Vivado 2025.2. If Vivado is available in `PATH`, rebuild from this directory with:

```powershell
vivado -mode batch -source .\.scripts\build_and_program.tcl
```

The current shell does not have `vivado` in `PATH`, so `artifacts/` contains the latest already-generated bitstream and reports found in the Vivado implementation run.

## Web UI

Start the local browser UI from this directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\webui\drum_webui.ps1
```

The server opens `http://127.0.0.1:8765/`. Connect the Cmod A7 USB UART, choose the COM port, then use pads 1-8 or the 16-step sequencer. The `Load Bank` button streams `src/rtl/generated/sample_bank.hex` to the FPGA over the same serial protocol as the desktop helpers.

### USB MIDI controllers

USB MIDI controllers such as the Arturia MiniLab 3 should be connected to the PC, not directly to the Cmod A7. The browser UI can use Web MIDI in Chrome or Edge on `http://127.0.0.1:8765/` and forward Note On events to the FPGA over the selected UART port.

Click `Enable MIDI`, allow MIDI access in the browser, then choose the MiniLab input if it is not selected automatically. The default map follows common GM drum notes:

- C1 / 36 - kick
- D1 / 38 - snare
- F#1 / 42 - closed hihat
- A#1 / 46 - open hihat
- D#1 / 39 - clap
- A1 / 45 - low tom
- D2 / 50 - high tom
- C#2 / 49 - crash

The UI also accepts notes 36-43 as eight chromatic pads, and the `Learn` control can remap any pad to the next incoming MIDI note.

## MIDI DIN Adapter

The `hardware/midi_esp32_c3_supermini_adapter/` KiCad project sketches a DIN MIDI input adapter using an ESP32-C3 SuperMini as a bridge. It translates MIDI Note On messages to the same UART drum keys used by the Web UI.
