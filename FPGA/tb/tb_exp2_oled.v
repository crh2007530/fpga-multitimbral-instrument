`timescale 1ns/1ps
module tb_exp2_oled;
reg clk=0;always #5 clk=~clk;tri1 sda;
oled_status #(.EXTENDED(1),.EXPANSION(1),.EXPRESSION(1)) dut(
 .clk(clk),.rst_n(1'b0),.sda(sda),.expression_config(4'hf),.chord_mode(1'b1),
 .test32(1'b0),.test_mode(1'b0),.selected_test(5'd0),.mask32(32'hffffffff),
 .test_mask(4'hf),.selected(4'd8),.voice_modes(16'd0));
reg[111:0]ctx;reg[167:0]line;integer i;
initial begin #10;ctx=dut.live_context;
for(i=0;i<21;i=i+1)line[167-8*i-:8]=dut.text_char(3,i,0,0,ctx,0,0);
if(line!=="T:FLUT G:1 V:1 E:1   ")$fatal(1,"OLED expressions %s",line);
ctx[67:64]=0;
for(i=0;i<21;i=i+1)line[167-8*i-:8]=dut.text_char(3,i,0,0,ctx,0,0);
if(line!=="T:REED G:0 V:0 E:0   ")$fatal(1,"OLED default %s",line);
$display("PASS OLED actual snapshot bit mapping, both timbres and all three effect switches");$finish;end
endmodule
