`timescale 1ns/1ps
`undef __ICARUS__
module tb_v26_palette;
reg clk=0;always #5 clk=~clk;
wire hit;wire[23:0]rgb;
video_ship dut(clk,1'b0,11'd0,10'd0,1'b0,1'b0,8'd0,hit,rgb);
integer i,j,r,g,b;reg[2:0]lane;reg[3:0]level;reg[23:0]a,expected;
initial begin
force dut.lane=lane;force dut.level=level;
for(i=0;i<8;i=i+1)begin
lane=i;a=dut.accent(lane);
for(j=0;j<16;j=j+1)begin
level=j;r=((a>>16)&255)*j/16;g=((a>>8)&255)*j/16;b=(a&255)*j/16;
expected=(r<<16)|(g<<8)|b;#10;
if(dut.tail_rgb!==expected)$fatal(1,"native LUT4 palette mismatch lane=%d level=%d actual=%h expected=%h",i,j,dut.tail_rgb,expected);
end end
$display("PASS native Gowin LUT4 all 128 palette colors exactly match arithmetic reference");$finish;
end
endmodule
