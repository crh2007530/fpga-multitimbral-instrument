`timescale 1ns/1ps
module tb_epiano_select;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,clear=0,testmode=0,next=0,inc=0,dec=0;wire[1:0]mode;
 instrument_select dut(clk,rst,clear,testmode,next,inc,dec,mode);
 task step;input[2:0]events;input[1:0]expected;begin
 @(negedge clk);{next,inc,dec}=events;@(negedge clk);{next,inc,dec}=0;
 if(mode!==expected)$fatal(1,"mode got %d expected %d",mode,expected);
 end endtask
 initial begin
 repeat(3)@(negedge clk);rst=1;
 step(2,1);step(2,2);step(2,0);step(1,2);step(1,1);step(1,0);
 step(4,1);step(4,2);step(4,0);step(6,1);step(5,0);step(7,0);
 testmode=1;step(2,0);step(4,0);testmode=0;step(4,1);
 clear=1;step(2,0);clear=0;
 $display("PASS 3-way forward/reverse/legacy next, simultaneous priority, TEST inhibit, T8 clear");$finish;
 end
endmodule
