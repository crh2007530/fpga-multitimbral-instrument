`timescale 1ns/1ps
module tb_instrument_env;
reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,on=0,off=0,flute=0,diag=0;
wire[15:0] level,old;wire active,oa;
instrument_env dut(clk,rst,ce,on,off,flute,diag,level,active,1'b0);
adsr_env refenv(clk,rst,ce,on,off,old,oa,);
integer i;reg[15:0] peak;
task tick;begin @(negedge clk);ce=1;@(negedge clk);ce=0;end endtask
task press;begin @(negedge clk);on=1;@(negedge clk);on=0;end endtask
task release_note;begin @(negedge clk);off=1;@(negedge clk);off=0;end endtask
initial begin repeat(3)@(negedge clk);rst=1;
press;repeat(8)tick;if(level!=32767)$fatal(1,"pluck fast attack");
repeat(2048)tick;if(level>=10000 || level==0)$fatal(1,"pluck natural decay");
release_note;repeat(128)tick;if(active||level!=0)$fatal(1,"pluck release");
flute=1;press;repeat(128)tick;if(level!=32767)$fatal(1,"flute attack");
repeat(1024)tick;if(level!=24576 || !active)$fatal(1,"flute sustain");
release_note;repeat(512)tick;if(active)$fatal(1,"flute release");
rst=0;repeat(3)@(negedge clk);rst=1;diag=1;press;
for(i=0;i<5000;i=i+1)begin tick;if(level!==old || active!==oa)$fatal(1,"diagnostic envelope mismatch");end
release_note;
for(i=0;i<4000;i=i+1)begin tick;if(level!==old || active!==oa)$fatal(1,"diagnostic release mismatch");end
$display("PASS two presets: pluck attack/decay/release, flute attack/sustain/release, diagnostic legacy equivalence");$finish;end
endmodule
