`timescale 1ns/1ps
module tb_echo_production;
 reg clk=0;always #5 clk=~clk;reg rst=0,en=0,iv=0;reg signed[15:0] pcm=0;
 wire ov;wire signed[15:0] out;integer n,count=0;
 audio_echo #(.ADDR_BITS(13)) dut(clk,rst,en,iv,pcm,ov,out);
 task sample;input integer value,expected;begin
  @(negedge clk);iv=1;pcm=value;@(negedge clk);iv=0;
  @(negedge clk);if(!ov || out!==expected)$fatal(1,"8192-delay sample %0d expected %0d got %0d",count,expected,out);
  count=count+1;@(negedge clk);if(ov)$fatal(1,"duplicate");
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst=1;sample(-32768,-32768);sample(32767,32767);
  en=1;sample(16000,16000);
  for(n=1;n<8192;n=n+1)sample(0,0);sample(0,4000);
  for(n=1;n<8192;n=n+1)sample(0,0);sample(0,2000);
  en=0;sample(1234,1234);en=1;
  for(n=0;n<24576;n=n+1)sample(0,0);
  for(n=0;n<24576;n=n+1)sample(32767,32767);
  en=0;sample(0,0);en=1;
  for(n=0;n<24576;n=n+1)sample(-32768,-32768);
  $display("PASS %0d samples through production 8192-frame echo memory: exact 8192/16384-frame impulse tail, re-enable clears history, positive/negative feedback saturation, no duplicate output",count);$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
