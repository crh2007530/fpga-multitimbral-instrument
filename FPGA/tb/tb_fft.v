`timescale 1ns/1ps
module tb_fft;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,sv=0;reg signed[15:0] pcm=0;
 wire busy,bv,done;wire[9:0] bi;wire signed[23:0] re,im;wire[31:0] skipped;
 reg[15:0] inputs[0:12287];reg[47:0] expected[0:6143];
 integer c,n,count=0,cycles=0,startcycle;
 fft2048 dut(clk,rst,sv,pcm,busy,bv,bi,re,im,done,skipped);
 always @(posedge clk)begin
  cycles=cycles+1;#1;
  if(bv)begin
   if(bi !== count%1024 || {re,im} !== expected[count])
    $fatal(1,"FFT mismatch bin=%0d got=%h expected=%h",count,{re,im},expected[count]);
   count=count+1;
  end
 end
 initial begin
  $readmemh("input.hex",inputs);$readmemh("expected.hex",expected);
  repeat(5)@(negedge clk);rst=1;
  for(c=0;c<6;c=c+1)begin
   for(n=0;n<2048;n=n+1)begin
    @(negedge clk);sv=1;pcm=inputs[c*2048+n];
   end
   @(negedge clk);sv=0;startcycle=cycles;
   // A sample while processing is counted, never injected into FFT memory.
   repeat(3)@(negedge clk);sv=1;@(negedge clk);sv=0;
   wait(done);@(negedge clk);
   if(cycles-startcycle>105000)$fatal(1,"FFT deadline");
   if(skipped!=c+1)$fatal(1,"skip accounting");
  end
  if(count!=6144)$fatal(1,"bin count");
  $display("PASS 6 frames / 6144 exact complex bins: silence, impulse, DC, sine, random full range, 64 tones; <105000 cycles; skip accounting");$finish;
 end
 initial begin #20000000;$fatal(1,"timeout");end
endmodule
