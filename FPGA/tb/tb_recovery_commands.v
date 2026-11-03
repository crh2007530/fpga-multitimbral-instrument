`timescale 1ns/1ps
module tb_recovery_commands;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fv=0;reg[7:0] raw=0;
 wire valid,active,running,done,test_mode;wire[7:0] keys;
 wire[15:0] count;wire[7:0] last;
 touch_command_guard #(.TIMEOUT_CYCLES(100)) guard(clk,rst,fv,!active&&!test_mode,raw,valid,keys);
 performance_controls #(.EXPANSION(1)) play(.clk(clk),.rst_n(rst),.frame_valid(valid&&!active),.keys(keys),.clear(1'b0),.remote_valid(1'b0),.remote_keys(8'd0),.test_mode(test_mode),.command_count(count),.last_command(last));
 rhythm_game #(.CLOCK_HZ(1000)) game(.clk(clk),.rst_n(rst),.frame_valid(valid),.keys(keys),.pressed(8'd0),.test_mode(test_mode),.local_inhibit(1'b0),.remote_valid(1'b0),.remote_keys(8'd0),.remote_toggle(1'b0),.active(active),.running(running),.done(done));
 task frames;input[7:0] k;input integer n;integer j;begin
 for(j=0;j<n;j=j+1)begin @(negedge clk);raw=k;fv=1;@(negedge clk);fv=0;repeat(2)@(negedge clk);end
 end endtask
 integer i;
 initial begin
 repeat(4)@(negedge clk);rst=1;frames(0,6);
 frames(8,20);if(count!=1||last!=8)$fatal(1,"T4 command");
 frames(3,3);frames(1,20);if(count!=2||last!=1)$fatal(1,"T1 rollover recovery");
 frames(1,100);if(count!=2)$fatal(1,"held key repeats");
 frames(3,4);frames(1,20);if(count!=2)$fatal(1,"same key noise retrigger");
 frames(2,20);if(count!=3||last!=2)$fatal(1,"different key blocked");
 frames(0,6);frames(64,300);if(!active)$fatal(1,"T7 entry");frames(0,6);
 frames(16,12);if(!running)$fatal(1,"start");
 frames(3,4);frames(16,100);if(!running)$fatal(1,"spurious pause after conflict");
 for(i=0;i<10;i=i+1)begin
 frames(0,6);frames(16,12);if(running)$fatal(1,"pause");
 frames(0,6);frames(16,12);if(!running)$fatal(1,"resume");
 end
 frames(128,12);if(active)$fatal(1,"T8 rollover exit");
 if(test_mode)$fatal(1,"spurious automatic test audio");
 $display("PASS guard + real PLAY/game controls: conflict recovery, held once, same-key no retrigger, T7 entry, 10 T5 pause/resume pairs, T8 rollover exit");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
