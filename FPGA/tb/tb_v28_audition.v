`timescale 1ns/1ps
module tb_v28_audition;
reg clk=0;always #5 clk=~clk;reg rst=0,v=0;reg signed[15:0]pcm=0;reg[2:0]en=0;reg[32:0]cfg;
wire ov;wire signed[15:0]out;integer mode,n,f,amp,value,clip;reg[511:0]name;
audio_send_fx dut(clk,rst,v,pcm,cfg,en,1'b0,1'b0,ov,out);
task sample;input integer a;begin @(negedge clk);v=1;pcm=a;@(negedge clk);v=0;repeat(10)@(negedge clk);end endtask
initial begin
for(mode=0;mode<7;mode=mode+1)begin
rst=0;v=0;repeat(3)@(negedge clk);rst=1;
cfg={2'd1,2'd1,5'd8,3'd6,2'd2,5'd8,2'd1,2'd1,5'd8,5'd16};en=mode==0?0:mode<4?1:mode==4?2:mode==5?4:7;
if(mode<4 && mode>0)begin cfg[13:12]=mode-1;cfg[11:10]=mode-1;end
for(n=0;n<10000;n=n+1)sample(0);
$sformat(name,"checks/v28_effect_%0d.txt",mode);f=$fopen(name,"w");clip=0;
for(n=0;n<96000;n=n+1)begin
amp=n<24000?(24000-n)/4:0;
value=$rtoi(amp*($sin(n*0.0575959)+0.35*$sin(n*0.1151917)+0.15*$sin(n*0.1727876)));
sample(value);if(^out===1'bx)$fatal(1,"unknown audition sample");if(out==32767 || out== -32768)clip=clip+1;$fdisplay(f,"%d",out);
end
$fclose(f);if(clip)$fatal(1,"audition clipped %d",clip);
end
$display("PASS 7 real Send-bus audio renders from identical synthetic excitation, no clipping/unknown outputs");$finish;end
endmodule
