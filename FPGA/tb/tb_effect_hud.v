`timescale 1ns/1ps
module tb_effect_hud;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg[127:0]state=0;reg[10:0]x=128;reg[9:0]y=696;
video_labels dut(state,clk,rst,x,y,1'b0,1'b0,1'b1,24'd0,,,,,1'b0,22'd0,64'd0,9'd0,1'b0,24'd0);
integer bits,j,offset;reg enabled;reg[7:0]on_code,off_code;
initial begin
repeat(4)@(negedge clk);rst=1;
// IDs are read from generated metadata by the preparation step below.
on_code=8'd0;off_code=8'd0;
`include "tb/effect_codes.vh"
for(bits=0;bits<32;bits=bits+1)begin
state[118]=(bits&1)!=0;state[119]=(bits&2)!=0;state[123]=(bits&4)!=0;state[124]=(bits&8)!=0;state[122]=(bits&16)!=0;
for(j=0;j<5;j=j+1)begin
 x=128+(3+j*5)*16;enabled=(bits&(1<<j))!=0;#1;
 if(dut.letter!==(enabled?on_code:off_code))$fatal(1,"effect state mask=%d item=%d",bits,j);
end
state[127]=1;
for(j=0;j<5;j=j+1)begin x=128+(3+j*5)*16;#1;if(dut.letter!==off_code)$fatal(1,"TEST must bypass FX");end
state[127]=0;
end
state[30]=1;x=128;repeat(6)@(negedge clk);
if(dut.use_game || !dut.ft || dut.fl!==dut.FX[511:504])$fatal(1,"game footer missing");
y=16;repeat(6)@(negedge clk);if(!dut.use_game)$fatal(1,"game title displaced");
$display("PASS all32 FX combinations, TEST bypass and shared footer on game/dashboard");$finish;
end
endmodule
