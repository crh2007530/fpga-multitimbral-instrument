`timescale 1ns/1ps
module tb_web_envelope;
reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,on=0,off=0,piano=0,guitar=0,diag=0;
wire[15:0]level,reference;wire active,ra;
instrument_env #(.THIRD_TIMBRE(1)) dut(clk,rst,ce,on,off,guitar,diag,level,active,piano);
adsr_env refenv(clk,rst,ce,on,off,reference,ra,);
task tick;begin @(negedge clk);ce=1;@(negedge clk);ce=0;end endtask
task press;begin @(negedge clk);on=1;@(negedge clk);on=0;end endtask
task release_note;begin @(negedge clk);off=1;@(negedge clk);off=0;end endtask
integer kind,i,previous;
initial begin
for(kind=0;kind<3;kind=kind+1)begin
rst=0;repeat(3)@(negedge clk);rst=1;piano=kind==2;guitar=kind==1;press;
repeat(2000)tick;if(level!=32767 || !active)$fatal(1,"gate attenuates onset model");
release_note;previous=level;
for(i=0;i<24024;i=i+1)begin tick;if(level>previous)$fatal(1,"release wrapped");previous=level;end
if(active || level!=0)$fatal(1,"release stuck");
press;repeat(100)tick;if(!active || level!=32767)$fatal(1,"retrigger");
end
rst=0;repeat(3)@(negedge clk);rst=1;diag=1;press;
for(i=0;i<8000;i=i+1)begin tick;if(level!==reference || active!==ra)$fatal(1,"diagnostic envelope");end
release_note;for(i=0;i<5000;i=i+1)begin tick;if(level!==reference || active!==ra)$fatal(1,"diagnostic release");end
$display("PASS three musical gates, monotone release under0.5s, retrigger, and exact diagnostic ADSR; musical onsets/decays verified independently in bank vectors");$finish;
end
endmodule
