`timescale 1ns/1ps
module tb_instrument_state;
reg clk=0;always #5 clk=~clk;reg rst=0,ce=0,testmode=0,flute=0;
wire held,active;wire[9:0] addr;wire[15:0] forcev,env;
pressure_voice_state #(.INSTRUMENTS(1)) dut(.clk(clk),.rst_n(rst),.sample_ce(ce),.pressure_valid(1'b1),.phase_ce(1'b0),.pressure_raw(8'd128),.phase_inc(32'd10000000),.flute_mode(flute),.test_mode(testmode),.held(held),.envelope_active(active),.address(addr),.force_snapshot(forcev),.envelope_snapshot(env));
integer i;
task tick;begin @(negedge clk);ce=1;@(negedge clk);ce=0;repeat(5)@(negedge clk);end endtask
initial begin repeat(4)@(negedge clk);rst=1;repeat(10)@(negedge clk);
repeat(12000)tick;if(active)$fatal(1,"pluck must decay despite held pad");
testmode=1;repeat(10)@(negedge clk);repeat(5000)tick;
if(!held || !active || env!=19660)$fatal(1,"test entry while pad held must retrigger diagnostic sustain");
testmode=0;flute=1;repeat(10)@(negedge clk);repeat(2000)tick;
if(!active || env!=24576)$fatal(1,"test exit must resume selected flute preset");
$display("PASS instrument state: held pluck decays; diagnostic entry/exit retriggers correct sustain; no held-key diagnostic dropout");$finish;end
endmodule
