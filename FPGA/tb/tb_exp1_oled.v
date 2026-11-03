`timescale 1ns/1ps
module tb_exp1_oled;
reg clk=0;always #5 clk=~clk;tri1 sda;
oled_status #(.EXTENDED(1),.EXPANSION(1)) dut(.clk(clk),.rst_n(1'b0),.sda(sda),.chord_mode(1'b1),.test32(1'b1),.selected_test(5'd31),.mask32(32'h7ffffffe),.test_mode(1'b1),.test_mask(4'hf),.selected(4'd0),.voice_modes(16'd0));
reg[111:0]ctx;reg[167:0]line;integer i;
initial begin #10;ctx=dut.live_context;
for(i=0;i<21;i=i+1)line[167-8*i-:8]=dut.text_char(0,i,0,0,ctx,0,0);
if(line!=="FFT PURE 32 VOICES   ")$fatal(1,"OLED 32 header %s",line);
if(dut.text_char(2,5,0,0,ctx,0,0)!="3"||dut.text_char(2,6,0,0,ctx,0,0)!="2")$fatal(1,"OLED V32");
if(dut.text_char(3,5,0,0,ctx,0,0)!="7"||dut.text_char(3,12,0,0,ctx,0,0)!="E")$fatal(1,"OLED mask hex");
ctx[24]=0;ctx[26]=0;
for(i=0;i<21;i=i+1)line[167-8*i-:8]=dut.text_char(0,i,0,0,ctx,0,0);
if(line!=="CHORD 32  8 PADS X4  ")$fatal(1,"OLED chord header");
$display("PASS OLED snapshot context: CHORD32, FFT32, V32 and eight-digit mask");$finish;end
endmodule
