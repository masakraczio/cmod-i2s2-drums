set_property PACKAGE_PIN L17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 83.333 -name sys_clk [get_ports clk]
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks audio_clk_raw]

# USB UART.
set_property PACKAGE_PIN J17 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property PACKAGE_PIN J18 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# Pmod JA top row -> Pmod I2S2 Line Out pins 1..4.
set_property PACKAGE_PIN G17 [get_ports da_mclk]
set_property IOSTANDARD LVCMOS33 [get_ports da_mclk]

set_property PACKAGE_PIN G19 [get_ports da_lrck]
set_property IOSTANDARD LVCMOS33 [get_ports da_lrck]

set_property PACKAGE_PIN N18 [get_ports da_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports da_sclk]

set_property PACKAGE_PIN L18 [get_ports da_sdin]
set_property IOSTANDARD LVCMOS33 [get_ports da_sdin]

set_property PACKAGE_PIN A18 [get_ports {btn[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[0]}]

set_property PACKAGE_PIN B18 [get_ports {btn[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[1]}]

set_property PACKAGE_PIN A17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN C16 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

# Onboard 512 KB asynchronous SRAM ("Cell RAM" in Digilent board files).
set_property PACKAGE_PIN M18 [get_ports {ram_addr[0]}]
set_property PACKAGE_PIN M19 [get_ports {ram_addr[1]}]
set_property PACKAGE_PIN K17 [get_ports {ram_addr[2]}]
set_property PACKAGE_PIN N17 [get_ports {ram_addr[3]}]
set_property PACKAGE_PIN P17 [get_ports {ram_addr[4]}]
set_property PACKAGE_PIN P18 [get_ports {ram_addr[5]}]
set_property PACKAGE_PIN R18 [get_ports {ram_addr[6]}]
set_property PACKAGE_PIN W19 [get_ports {ram_addr[7]}]
set_property PACKAGE_PIN U19 [get_ports {ram_addr[8]}]
set_property PACKAGE_PIN V19 [get_ports {ram_addr[9]}]
set_property PACKAGE_PIN W18 [get_ports {ram_addr[10]}]
set_property PACKAGE_PIN T17 [get_ports {ram_addr[11]}]
set_property PACKAGE_PIN T18 [get_ports {ram_addr[12]}]
set_property PACKAGE_PIN U17 [get_ports {ram_addr[13]}]
set_property PACKAGE_PIN U18 [get_ports {ram_addr[14]}]
set_property PACKAGE_PIN V16 [get_ports {ram_addr[15]}]
set_property PACKAGE_PIN W16 [get_ports {ram_addr[16]}]
set_property PACKAGE_PIN W17 [get_ports {ram_addr[17]}]
set_property PACKAGE_PIN V15 [get_ports {ram_addr[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_addr[*]}]

set_property PACKAGE_PIN W15 [get_ports {ram_dq[0]}]
set_property PACKAGE_PIN W13 [get_ports {ram_dq[1]}]
set_property PACKAGE_PIN W14 [get_ports {ram_dq[2]}]
set_property PACKAGE_PIN U15 [get_ports {ram_dq[3]}]
set_property PACKAGE_PIN U16 [get_ports {ram_dq[4]}]
set_property PACKAGE_PIN V13 [get_ports {ram_dq[5]}]
set_property PACKAGE_PIN V14 [get_ports {ram_dq[6]}]
set_property PACKAGE_PIN U14 [get_ports {ram_dq[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ram_dq[*]}]

set_property PACKAGE_PIN N19 [get_ports ram_ce_n]
set_property IOSTANDARD LVCMOS33 [get_ports ram_ce_n]

set_property PACKAGE_PIN P19 [get_ports ram_oe_n]
set_property IOSTANDARD LVCMOS33 [get_ports ram_oe_n]

set_property PACKAGE_PIN R19 [get_ports ram_we_n]
set_property IOSTANDARD LVCMOS33 [get_ports ram_we_n]
