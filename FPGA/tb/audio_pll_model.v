`timescale 1ns/1ps
// TESTBENCH ONLY. Ideal parameter-derived clock and representative lock delay.
// Not an analog PLL model and never included in the Gowin build.
module audio_pll(input clkin, input mdclk, output reg clkout0=0, output reg lock=0);
    always #20.325203252 clkout0=~clkout0;
    initial begin #1800000; lock=1; end
endmodule
