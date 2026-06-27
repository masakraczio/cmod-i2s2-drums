# Build Artifacts

Version: 0.4.6

These files were copied from the latest available Vivado implementation output in `pmod_i2s2_drums.runs/impl_1`.

Vivado was not available in `PATH` during repository preparation, so the FPGA bitstream files represent the last known successful local build rather than a freshly regenerated HDL build. The Web UI and hardware starter artifacts were rebuilt for this version.

Included artifacts:

- `cmod_i2s2_drums.bit`
- `cmod_i2s2_drums_utilization_placed.rpt`
- `cmod_i2s2_drums_timing_summary_routed.rpt`
- `cmod_i2s2_drums_route_status.rpt`
- `cmod-i2s2-drums-webui-0.4.6.zip`
- `midi-esp32-c3-supermini-adapter-0.4.6.zip`

The MIDI adapter KiCad schematic was checked with KiCad ERC: 0 violations.
The MIDI adapter KiCad PCB placeholder was checked with KiCad DRC: 0 violations, 0 unconnected items.
The ESP32-C3 SuperMini accelerating/decelerating blink test was compiled and uploaded to COM7 with Arduino CLI 1.5.1 and esp32 core 3.3.10.
The ESP32-C3 SuperMini MIDI DIN input diagnostic with raw-byte, GPIO20 edge counters, and active-low LED handling was compiled and uploaded to COM7 with Arduino CLI 1.5.1 and esp32 core 3.3.10.
