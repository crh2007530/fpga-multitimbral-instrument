`timescale 1ns/1ps
module tb_v22_oled_speed;
reg clk=0;always #5 clk=~clk;reg rst=0;wire[1343:0] textout;
oled_status #(.EXTENDED(1),.EXPANSION(1),.TRAINER(1),.HDMI_STATUS(1)) dut(.clk(clk),.rst_n(rst),.screen_text(textout));
reg[127:0]ctx;integer d,i;reg[167:0]line;reg[7:0]ch;
initial begin
ctx=0;ctx[70]=1;
for(d=0;d<3;d=d+1)begin ctx[77:76]=d;
for(i=0;i<21;i=i+1)line[167-i*8-:8]=dut.text_char(1,i,0,0,ctx,0,0);
if(d==0 && line!="PAUSE BPM:060 RHYTHM ")$fatal(1,"slow %s",line);
if(d==1 && line!="PAUSE BPM:120 RHYTHM ")$fatal(1,"standard %s",line);
if(d==2 && line!="PAUSE BPM:240 RHYTHM ")$fatal(1,"fast %s",line);
end
ctx[75:74]=1;
for(i=0;i<21;i=i+1)line[167-i*8-:8]=dut.text_char(1,i,0,0,ctx,0,0);
if(line!="PAUSE CUSTOM TEMPO   ")$fatal(1,"custom %s",line);
ctx[70]=0;
for(i=0;i<21;i=i+1)line[167-i*8-:8]=dut.text_char(4,i,0,0,ctx,0,0);
if(line!="HDMI: WAVE FFT XY    ")$fatal(1,"HDMI status label %s",line);
$display("PASS OLED 60/120/240 and uploaded-score label; no legacy16-step progress");$finish;end
endmodule
