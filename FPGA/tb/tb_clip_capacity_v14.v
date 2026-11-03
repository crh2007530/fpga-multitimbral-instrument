`timescale 1ns/1ps
module tb_clip_capacity_v14;
 reg clk=0;always #5 clk=~clk;reg rst=0,start=0,stop=0,valid=0;reg signed[15:0] pcm=0;
 wire recording,ready;wire[15:0] count;reg[14:0] addr=0;wire[7:0] data;
 pcm_clip_recorder dut(clk,rst,start,stop,valid,pcm,recording,ready,count,addr,data);
 integer i,j;reg[7:0] expected;
 initial begin
  repeat(3)@(negedge clk);rst=1;start=1;@(negedge clk);start=0;valid=1;
  for(i=0;i<32768;i=i+1)begin pcm=(i%256-128)*256;repeat(4)@(negedge clk);end
  if(count!=32768 || recording || !ready)$fatal(1,"capacity status");
  repeat(20)@(negedge clk);valid=0;
  for(i=0;i<32768;i=i+1)begin addr=i;repeat(2)@(negedge clk);expected=i%256;if(data!==expected)$fatal(1,"readback addr=%d actual=%d expected=%d",i,data,expected);end
  $display("PASS production 32768-byte capture, all 256 unsigned values, every address readback, automatic stop no overwrite");$finish;
 end
endmodule
