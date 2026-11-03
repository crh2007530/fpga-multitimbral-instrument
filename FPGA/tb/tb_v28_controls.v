`timescale 1ns/1ps
module tb_v28_controls;
reg clk=0;always #5 clk=~clk;reg rst=0,blocked=0,open=0,next=0,prev=0,inc=0,dec=0;reg[2:0]base=0;reg remote=0,echo_event=0,echo_clear=0;
wire active;wire[3:0]item;wire[32:0]cfg;wire[2:0]en,edit;wire[1:0]ep,cp;integer i;
mixer_controls dut(clk,rst,blocked,open,next,prev,inc,dec,base,active,item,cfg,en,ep,cp,edit,remote,echo_event,echo_clear);
task tick;begin @(negedge clk);end endtask
task advance;begin next=1;tick;next=0;tick;end endtask
task turn;begin inc=1;tick;inc=0;tick;end endtask
reg key=1;wire sp,lp;integer shorts=0,longs=0;
ui_press #(.FILTER(3),.LONG(12)) button(clk,rst,key,sp,lp);
always @(posedge clk)if(rst)begin if(sp)shorts=shorts+1;if(lp)longs=longs+1;end
initial begin repeat(3)tick;rst=1;repeat(10)tick;
turn;if(cfg[4:0]!=16 || active)$fatal(1,"outside mixer changed");
open=1;tick;open=0;tick;if(!active)$fatal(1,"open");turn;if(en!=1)$fatal(1,"rev enable");
advance;turn;if(cfg[13:12]!=1 || cfg[11:10]!=1 || cfg[9:5]!=12)$fatal(1,"room preset");
advance;repeat(30)turn;if(cfg[9:5]!=16)$fatal(1,"wet clamp");
repeat(3)advance;turn;if(ep!=2 || cfg[23:21]!=4 || cfg[20:19]!=1)$fatal(1,"echo preset");
repeat(5)advance;turn;if(cp!=1 || cfg[30:29]!=1 || cfg[32:31]!=1)$fatal(1,"chorus preset");
repeat(4)advance;dec=1;repeat(30)tick;dec=0;tick;if(cfg[4:0]!=0)$fatal(1,"dry clamp");
base=4;repeat(3)tick;if(en!=5)$fatal(1,"remote override");remote=1;tick;remote=0;tick;if(en!=4)$fatal(1,"same-value app OFF must override panel ON");
echo_event=1;tick;echo_event=0;tick;if(en!=6)$fatal(1,"gesture echo on");echo_event=1;tick;echo_event=0;tick;if(en!=4)$fatal(1,"gesture echo off");
blocked=1;tick;tick;if(active)$fatal(1,"game lock");
key=0;repeat(10)tick;key=1;repeat(12)tick;if(shorts!=1 || longs!=0)$fatal(1,"short click");
key=0;repeat(40)tick;key=1;repeat(12)tick;if(shorts!=1 || longs!=1)$fatal(1,"long double-fired");
$display("PASS page isolation, preset values, gain bounds, external override, game/test lock, debounced short/long no duplicate");$finish;
end
endmodule

