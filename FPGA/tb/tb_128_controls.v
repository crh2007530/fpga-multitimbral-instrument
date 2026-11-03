`timescale 1ns/1ps
module tb_128_controls;
reg clk=0;always #10 clk=~clk;
reg rst=0,rv=0,fv=0,clear=0;reg[7:0]rk=0,keys=0;
wire[127:0]mask;wire[6:0]sel;wire tm,t32,chord;wire[15:0]modes,count;wire[3:0]target,mask4;wire[1:0]mode;wire[7:0]last;
performance_controls #(.TEST_VOICES(128),.EXPANSION(1),.REMOTE(1),.EXTERNAL_CLEAR(1)) dut(clk,rst,fv,clear,rv,rk,keys,modes,target,tm,mask4,mode,count,last,chord,t32,sel,mask);
task command;input[7:0]k;begin @(negedge clk);rv=1;rk=k;@(negedge clk);rv=0;@(negedge clk);end endtask
integer i;reg[127:0]expected;
initial begin
 repeat(4)@(negedge clk);rst=1;
 command(32);command(16);if(!tm || !t32 || mask!==~128'd0)$fatal(1,"entry");
 expected=~128'd0;
 for(i=0;i<128;i=i+1)begin
  if(sel!=i)$fatal(1,"selection %0d",i);
  command(32);expected[i]=0;if(mask!==expected)$fatal(1,"mute independence %0d",i);
  command(8);
 end
 if(mask!=0 || sel!=0)$fatal(1,"wrap/all off");
 command(64);if(mask!==~128'd0)$fatal(1,"all restore");
 command(2);if(sel!=64)$fatal(1,"bank2");command(4);if(sel!=63)$fatal(1,"previous crossing");
 command(1);if(sel!=0)$fatal(1,"bank1");command(4);if(sel!=127)$fatal(1,"previous wrap");
 command(32);if(mask!==(~(128'd1<<127)))$fatal(1,"last independent");
 command(128);if(tm || t32 || chord || modes!=0)$fatal(1,"exit restore");
 command(1);if(modes!={8{2'd1}})$fatal(1,"normal octave regressed");
 // Real touch path: two matching samples accept once, held samples do not repeat.
 keys=32;fv=1;repeat(8)@(negedge clk);fv=0;if(!chord)$fatal(1,"held touch repeat");
 keys=0;fv=1;repeat(3)@(negedge clk);keys=32;repeat(4)@(negedge clk);fv=0;
 if(chord)$fatal(1,"touch release/repress");
 clear=1;@(negedge clk);clear=0;if(mask!==~128'd0)$fatal(1,"clear");
 $display("PASS 128 independent mute bits, bank jumps, forward/backward boundary wrap, restore, exit, ordinary octave and held-touch debounce");$finish;
end
endmodule
