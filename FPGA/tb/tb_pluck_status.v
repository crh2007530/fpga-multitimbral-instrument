`timescale 1ns/1ps
module tb_pluck_status;
reg clk=0;always #5 clk=~clk;
reg rst=0,en=0,toggle=0,inhibit=0,blocked=0,armed=0,event_pulse=0;
reg[7:0] gates=0;wire[1:0] result;wire[23:0] data;
pluck_note_observer #(.WAIT_CYCLES(12)) obs(clk,rst,en,toggle,gates,result);
pluck_status #(.HOLD_CYCLES(8)) ui(clk,rst,en,inhibit,blocked,armed,event_pulse,result,data);
task cycles;input integer n;begin repeat(n)@(negedge clk);end endtask
task pluck;begin toggle=~toggle;event_pulse=1;cycles(1);event_pulse=0;cycles(1);end endtask
integer i;
initial begin
cycles(3);rst=1;cycles(2);
gates=1;cycles(2);if(result!=0)$fatal(1,"disabled gate accepted");
en=1;cycles(3);if(result!=0)$fatal(1,"enable fabricated note");
pluck;cycles(14);if(result!=2 || data[23:8]!=1)$fatal(1,"no-new-gate result");
gates=0;cycles(2);pluck;gates=3;cycles(2);
if(result!=3 || data[6:5]!=3 || !data[4])$fatal(1,"real gate missing");
cycles(10);if(data[4] || result!=3)$fatal(1,"feedback hold or result retention");
inhibit=1;cycles(1);if(data[6:3]!=0 || !data[1])$fatal(1,"mode inhibition display");
inhibit=0;gates=0;cycles(2);pluck;en=0;cycles(2);gates=1;cycles(2);
if(result!=0 || data[6:3]!=0)$fatal(1,"disable did not clear feedback");
en=1;cycles(3);pluck;cycles(14);if(result!=2)$fatal(1,"re-enable held key fabricated trigger");
// Every BCD carry and saturation, independent of the binary optical counter.
for(i=4;i<10020;i=i+1)begin event_pulse=1;cycles(1);event_pulse=0;cycles(1);end
if(data[23:8]!=16'h9999)$fatal(1,"BCD saturation");
$display("PASS pluck status: actual gate edge, no-note timeout, enable/disable, inhibition,200ms-scaled hold,BCD carries/saturation");$finish;
end
endmodule
