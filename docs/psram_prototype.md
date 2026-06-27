# CMOD A7 PSRAM Prototype Notes

The working audio path stays on the Pmod I2S2. Do not breadboard an analog DAC for this stage; keep `MCLK`, `LRCK`, `SCLK`, and `SDIN` exactly as the current design uses them.

## Memory Roles

- `24LC1025`/`24LC01025C`: I2C EEPROM for presets, patterns, UI state, and calibration data. It is not suitable for streaming samples.
- SPI/QSPI PSRAM: external 3.3 V sample memory. The first FPGA step is a write/read smoke test; sample streaming comes after that is stable.

## Breadboard Wiring

Use a 3.3 V PSRAM breakout/module, not a raw BGA chip. Keep wires short and put a 100 nF capacitor directly between VCC and GND on the module.

Minimum single-SPI wiring for the smoke test:

| PSRAM signal | CMOD A7 signal |
| --- | --- |
| VCC | 3V3 |
| GND | GND |
| CS# | `psram_cs_n` |
| SCLK | `psram_sck` |
| SI / SIO0 | `psram_mosi` |
| SO / SIO1 | `psram_miso` |

For QSPI-capable parts, leave SIO2/SIO3 pulled high if the breakout does not already do it. They will be used in a later faster controller.

The Pmod I2S2 already occupies the JA audio pins, so choose PSRAM pins on the CMOD side headers after the exact module and mechanical layout are known. Add those pins to a separate smoke-test XDC before programming `cmod_psram_smoke_top`.

## Test Flow

1. Build a temporary smoke-test bitstream using `cmod_psram_smoke_top`.
2. Press BTN0 to run the test.
3. LED0 on means active/pass.
4. LED1 on means fail.
5. After stable write/read at low SPI speed, raise the SPI clock and then integrate buffered sample reads into the drum engine.

## Integration Path

The current sampler still uses generated sample ROMs in FPGA LUTs. The next code step is to replace those ROM reads with a PSRAM-backed sample fetcher:

- UART receives a sample bank from the PC UI.
- FPGA writes bank bytes to PSRAM.
- Each voice gets a small prefetch buffer.
- The mixer consumes prefetched PCM and keeps the Pmod I2S2 output unchanged.
