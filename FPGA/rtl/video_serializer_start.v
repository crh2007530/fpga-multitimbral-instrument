`timescale 1ns/1ps
// UG306 DHCE: dedicated HCLK gate, active-low CEN, four falling-edge
// synchronization stages. No LUT-gated clocks. On loss of ready reset
// asserts asynchronously; before each release the clock has been stopped
// for at least eight pixel periods. Release then precedes gate enable by
// eight further pixel periods (>107 ns at 74.1667 MHz).
module video_serializer_start(input pixel_clk,ready,serial_clk,
 output reg serializer_rst_n=0,output gated_clk);
 reg [4:0] count=0;
 reg gate_disable=1;
 always @(posedge pixel_clk or negedge ready)
 if(!ready)begin count<=0;serializer_rst_n<=0;gate_disable<=1;end
 else begin
   if(count!=31)count<=count+1'b1;
   if(count==7)serializer_rst_n<=1;
   if(count==15)gate_disable<=0;
 end
 DHCE fast_gate(.CLKIN(serial_clk),.CEN(gate_disable),.CLKOUT(gated_clk));
endmodule
