`timescale 1ns/1ps
module tb_pitch_dsp;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,ce=0,g=0,v=0;reg[31:0] target=0,rng=32'hb123abcd;
 reg signed[4:0] lfo=0;wire[31:0] a,b;
 expression_pitch old(.clk(clk),.rst_n(rst),.sample_ce(ce),.glide(g),.vibrato(v),.target(target),.lfo(lfo),.phase_inc(a));
 expression_pitch_dsp dut(.clk(clk),.rst_n(rst),.sample_ce(ce),.glide(g),.vibrato(v),.target(target),.lfo(lfo),.phase_inc(b));
 integer i;
 initial begin
 repeat(3)@(negedge clk);rst=1;
 for(i=0;i<100000;i=i+1)begin
  @(negedge clk);rng=(rng<<1)^(rng[31]?32'h04c11db7:0);
  target=rng;ce=rng[4];g=rng[5];v=rng[6];lfo=(i%17)-8;
  if(i%1000==0)target=0;if(i%1000==1)target=32'hffffffff;
  #1;if(a!==b)$fatal(1,"preedge mismatch %d",i);
  @(posedge clk);#1;if(a!==b || old.current!==dut.current)$fatal(1,"state mismatch %d",i);
 end
 $display("PASS 100000 pitch vectors: exact original state/output, full unsigned range, glide/vibrato/LFO boundaries");$finish;
 end
endmodule
