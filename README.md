# Cmod A7 Pmod I2S2 Drum Computer

FPGA drum computer prototype for the Digilent Cmod A7-35T with Pmod I2S2 stereo audio output.

## Contents

- `src/` - SystemVerilog RTL for the drum engine, I2S top level, PSRAM/SRAM experiments, and support blocks.
- `constrs/` - Cmod A7 pin constraints.
- `src/rtl/generated/` - generated drum sample ROM data used by the current RTL.
- `drum_pad.ps1` and `drum_sequencer_ui.ps1` - Windows helper UI scripts.
- `webui/` - browser UI served by a local PowerShell HTTP-to-serial bridge.
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
