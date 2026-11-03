`timescale 1ns/1ps
module tb_localfirst_arbitration;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fv=0,rv=0,rt=0;reg[7:0] keys=0,rk=0;
 wire active,running,done,test_mode;
 rhythm_game #(.CLOCK_HZ(1000)) game(.clk(clk),.rst_n(rst),.frame_valid(fv),.keys(keys),.pressed(8'd0),
 .test_mode(1'b0),.local_inhibit(1'b0),.remote_valid(rv),.remote_keys(rk),.remote_toggle(rt),
 .active(active),.running(running),.done(done));
 performance_controls #(.EXPANSION(1),.REMOTE(1)) play(.clk(clk),.rst_n(rst),.frame_valid(fv),.keys(keys),
 .clear(1'b0),.remote_valid(rv),.remote_keys(rk),.test_mode(test_mode));
 task remote_key;input[7:0] k;begin @(negedge clk);rv=1;rk=k;@(negedge clk);rv=0;end endtask
 task local_key;input[7:0] k;begin
 @(negedge clk);fv=1;keys=k;repeat(4)@(negedge clk);fv=0;
 end endtask
 initial begin
 repeat(4)@(negedge clk);rst=1;
 @(negedge clk);rt=1;@(negedge clk);rt=0;
 remote_key(16);if(!running)$fatal(1,"remote-only start lost");
 // Local T8 and remote T5 on the exact application edge.
 @(negedge clk);fv=1;keys=128;
 @(negedge clk);
 // PLAY controls execute on second stable frame.
 rv=1;rk=16;
 @(negedge clk);
 if(test_mode)$fatal(1,"remote beat local PLAY reset");
 // Game command is registered; keep remote until its application edge.
 rt=1;
 @(negedge clk);rv=0;rt=0;fv=0;
 if(active)$fatal(1,"remote beat local T8 exit");
 local_key(0);
 @(negedge clk);rt=1;@(negedge clk);rt=0;
 local_key(16);if(!running)$fatal(1,"local start lost");
 local_key(0);
 @(negedge clk);fv=1;keys=16;
 repeat(2)@(negedge clk);rv=1;rk=16;
 @(negedge clk);rv=0;fv=0;
 if(running)$fatal(1,"simultaneous pause toggled twice");
 repeat(5)@(negedge clk);if(running)$fatal(1,"queued remote undid local pause");
 remote_key(16);if(!running)$fatal(1,"remote-only resume lost");
 $display("PASS local priority: simultaneous T8 versus remote key/mode toggle, same-cycle T5 once, no deferred undo; remote-only start/resume preserved");$finish;
 end
endmodule
