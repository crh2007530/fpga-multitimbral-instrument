`timescale 1ns/1ps
module tb_video_wave_capture;
 reg sc=0,pc=0;always #10 sc=~sc;always #7 pc=~pc;
 reg rst=0,sv=0,frame=0;reg signed[15:0] pcm=0;reg[9:0] idx=0;
 wire signed[8:0] out;wire visible;integer i,expected;
 video_wave_capture dut(sc,rst,sv,pcm,pc,rst,frame,idx,out,visible);
 initial begin
  repeat(5)@(negedge sc);rst=1;
  for(i=0;i<1024;i=i+1)begin @(negedge sc);sv=1;pcm=i*64-32768;end
  @(negedge sc);sv=0;
  repeat(20)@(negedge sc);
  if(dut.index!=0 || dut.request!=1 || visible)$fatal(1,"publication before frame boundary");
  // Sustained input while pending must not overwrite the published bank.
  sv=1;pcm=1234;repeat(30)@(negedge sc);sv=0;
  if(dut.index!=0)$fatal(1,"pending frame was overwritten");
  @(negedge pc);frame=1;@(negedge pc);frame=0;
  repeat(5)@(negedge pc);
  if(!visible || dut.shift!=9)$fatal(1,"AGC full-range peak");
  for(i=0;i<1024;i=i+1)begin
   @(negedge pc);idx=i;@(negedge pc);
   expected=(i*64-32768)>>>9;
   if(out!==expected[8:0])$fatal(1,"wave mismatch %d %d %d",i,out,expected);
  end
  $display("PASS1024 waveform: contiguous samples, pending-bank protection, frame-boundary CDC, full-scale signed AGC and every read pixel");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
