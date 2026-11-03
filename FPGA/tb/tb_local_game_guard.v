`timescale 1ns/1ps
module tb_local_game_guard;
reg clk=0;always #5 clk=~clk;
reg rst=0,fv=0;reg[7:0] raw=0;reg lock_local=0;
wire gv;wire[7:0] keys;wire active,running,done;
touch_command_guard guard(clk,rst,fv,!active,raw,gv,keys);
rhythm_game #(.CLOCK_HZ(10000)) game(.clk(clk),.rst_n(rst),.frame_valid(gv),.keys(keys),.pressed(8'd0),.test_mode(1'b0),
.remote_valid(1'b0),.remote_keys(8'd0),.remote_toggle(1'b0),.local_inhibit(lock_local),.active(active),.running(running),.done(done));
task scan;input[7:0] k;input integer n;integer j;begin
for(j=0;j<n;j=j+1)begin @(negedge clk);raw=k;fv=1;@(negedge clk);fv=0;repeat(26)@(negedge clk);end
end endtask
task press;input[7:0] k;begin scan(0,12);scan(k,12);scan(0,12);end endtask
initial begin
repeat(4)@(negedge clk);rst=1;
scan(0,12);scan(64,400);scan(0,12);
if(!active || running)$fatal(1,"enter");
press(16);if(!running)$fatal(1,"T5 start");
scan(0,1000);if(!running || done)$fatal(1,"autopause");
press(16);if(running)$fatal(1,"T5 pause");
press(16);if(!running)$fatal(1,"T5 resume");
press(128);if(active)$fatal(1,"T8 exit");
$display("PASS v15.3 guard + rhythm: long T7 enter, short T5 start/pause/resume, T8 exit, no pause from idle/misses");
// Demonstrate effect of the actual global inhibit input.
scan(64,400);scan(0,12);press(16);press(16);
if(running || !active)$fatal(1,"pause setup");
lock_local=1;press(16);press(128);
if(running || !active)$fatal(1,"lock reproduction");
$display("REPRO with local_inhibit=1: PAUSED and local T5/T8 unresponsive; cause of real inhibit not established");
lock_local=0;press(128);if(active)$fatal(1,"unlock exit");
$display("PASS unlock restores T8");$finish;
end
endmodule
