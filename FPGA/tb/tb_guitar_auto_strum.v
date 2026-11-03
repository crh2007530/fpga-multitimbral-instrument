`timescale 1ns/1ps
module tb_guitar_auto_strum;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,ce=0,en=1;reg[7:0]held=0;wire[31:0]groups;
 guitar_auto_strum dut(clk,rst,ce,en,held,groups);
 integer t,p,age[0:7],expected;reg[31:0]rng=32'h12345678;
 task tick;begin @(negedge clk);ce=1;@(negedge clk);ce=0;end endtask
 initial begin
  repeat(3)@(negedge clk);rst=1;held=1;
  for(t=1;t<=2000;t=t+1)begin
   tick();expected=t/576;if(expected>3)expected=3;
   if(groups[0]!==1 || groups[8] !== (expected>=1) || groups[16] !== (expected>=2) || groups[24] !== (expected>=3))$fatal(1,"wrong production gap at %0d",t);
  end
  // Independent pads, partial releases, retriggers, idle clocks and bypass.
  held=0;tick();for(p=0;p<8;p=p+1)age[p]=0;
  for(t=0;t<20000;t=t+1)begin
   @(negedge clk);
   if(t%137==0)begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};held=rng[7:0];end
   en=(t%3001!=0);ce=(t%3!=0);
   for(p=0;p<8;p=p+1)begin
    if(!en || !held[p])age[p]=0;else if(ce && age[p]<1728)age[p]=age[p]+1;
   end
   @(posedge clk);#1;
   for(p=0;p<8;p=p+1)begin
    expected=age[p]/576;
    if(groups[p]!==1 || groups[8+p]!==(!en || (held[p] && expected>=1)) || groups[16+p]!==(!en || (held[p] && expected>=2)) || groups[24+p]!==(!en || (held[p] && expected>=3)))$fatal(1,"independent pad scheduling failed %0d/%0d",t,p);
   end
  end
  rst=0;#1;if(groups!==32'h000000ff && en)$fatal(1,"reset failed");
  $display("PASS strum: exact576-sample spacing, four onset groups, 8 independent pads,20000 randomized clocks, early release/retrigger/bypass/reset; first group never blocked");$finish;
 end
endmodule
