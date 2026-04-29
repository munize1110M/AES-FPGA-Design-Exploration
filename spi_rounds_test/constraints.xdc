## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Reset Button
# Using BTNC (Center Button). It is active-high on the Nexys A7, 
# which perfectly matches the `if (reset)` logic in your SystemVerilog core.
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { reset }];

## Pmod Header JA (Connected to Raspberry Pi)
# Top Row
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { spi_cs_n }];   # JA1
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }];   # JA2
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { spi_miso }];   # JA3
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { spi_sclk }];   # JA4

# Bottom Row
set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { data_ready }]; # JA7