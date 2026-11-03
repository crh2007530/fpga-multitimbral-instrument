`timescale 1ns/1ps
module tb_pluck_pressure;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0,en=0,toggle=0;reg[7:0]valid=0;reg[63:0]raw=0;
wire[7:0]outvalid;wire[63:0]out;
pluck_pressure dut(clk,rst,ce,en,toggle,valid,raw,outvalid,out);
task control;begin @(negedge clk);ce=1;@(negedge clk);ce=0;end endtask
task input_sample;input[63:0]v;begin @(negedge clk);raw=v;valid=255;@(negedge clk);valid=0;end endtask
initial begin
repeat(3)@(negedge clk);rst=1;
input_sample(64'h8070605040302010);if(out!=raw)$fatal(1,"legacy bypass");
en=1;control();if(out!=0)$fatal(1,"enable triggered note");
repeat(3)control();if(out!=0)$fatal(1,"pressure alone triggered");
toggle=1;control();if(out!=0)$fatal(1,"missing retrigger gap");
control();if(out!=0)$fatal(1,"gap too short");control();
if(out!=64'h8070605040302010)$fatal(1,"selected pressure mismatch");
repeat(5)begin control();if(outvalid!=0)$fatal(1,"invented ADC freshness");end
input_sample(64'h8070605040302000);control();if(out[7:0]!=0 || out[15:8]!=32)$fatal(1,"release independent");
toggle=0;control();if(out!=0)$fatal(1,"second pluck retrigger");control();control();
if(out[15:8]!=32)$fatal(1,"second pluck lost");
en=0;control();if(out!=raw)$fatal(1,"restore pressure mode");
$display("PASS optical pressure selection, two-frame retrigger, independent release, stale-data watchdog preserved, bypass");$finish;
end
endmodule
