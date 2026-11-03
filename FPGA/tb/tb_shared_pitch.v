`timescale 1ns/1ps
module tb_shared_pitch;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,ce=0,g=0,v=0;reg signed[4:0]lf=0;
 reg[1023:0]targets=0;wire[1023:0]reference;
 wire valid,busy,overrun;wire[4:0]idx;wire[31:0]inc;
 shared_pitch_engine dut(clk,rst,ce,g,v,targets,lf,valid,idx,inc,busy,overrun,1'b0,56'd0,16'd0);
 genvar k;generate for(k=0;k<32;k=k+1)begin:r
 expression_pitch_dsp refpitch(clk,rst,ce,g,v,targets[k*32+:32],lf,reference[k*32+:32]);
 end endgenerate
 reg[1023:0]expected;reg[31:0] rng=32'h81b3f971;
 integer trial,j,cycles,count,total=0;
 initial begin
 repeat(4)@(negedge clk);rst=1;
 for(trial=0;trial<1200;trial=trial+1)begin
  @(negedge clk);
  if(trial%157==156)begin rst=0;repeat(3)@(negedge clk);rst=1;end
  g=trial%7!=0;v=trial%3!=0;lf=trial%32;
  for(j=0;j<32;j=j+1)begin
   rng=(rng<<1)^(rng[31]?32'h04c11db7:0);
   if(trial<32)targets[j*32+:32]=trial*16+j;
   else if(trial%17==0)targets[j*32+:32]=32'hffffffff-j;
   else targets[j*32+:32]=rng;
  end
  #1;expected=reference;ce=1;
  @(negedge clk);ce=0;count=0;cycles=0;
  // Change live inputs: engine must use only the request snapshot.
  targets=~targets;g=~g;v=~v;lf=~lf;
  while(busy || valid)begin
   #1;if(valid)begin
    if(inc!==expected[idx*32+:32])$fatal(1,"trial=%0d lane=%0d got=%h expected=%h",trial,idx,inc,expected[idx*32+:32]);
    if(idx!==count)$fatal(1,"lane sequence");count=count+1;total=total+1;
   end
   cycles=cycles+1;if(cycles>38)$fatal(1,"deadline");
   @(negedge clk);
  end
  if(count!=32 || overrun)$fatal(1,"missing lanes or overrun");
 end
 // A too-early request must be detected, not silently accepted.
 ce=1;@(negedge clk);ce=0;repeat(3)@(negedge clk);ce=1;@(negedge clk);ce=0;
 if(!overrun)$fatal(1,"overrun not detected");
 $display("PASS %0d exact pitch results: 1200 frames, full-width arithmetic, all signed LFO values, glide/vibrato toggles, reset, input snapshots, <=37-cycle publication, overlap detection",total);$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule

