`timescale 1ns/1ps
module tb_touch_guard_v15_3;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fv=0;reg[7:0] raw=0;reg lesson=0;
 wire valid;wire[7:0] keys;wire test_mode,test32,chord;
 wire[15:0] commands;wire[7:0] last;
 wire legacy_test;wire[15:0] modes;wire[3:0] mask;wire[63:0] masks;
 touch_command_guard #(.STABLE_FRAMES(4),.RELEASE_FRAMES(4),.TEST_FRAMES(12),.TIMEOUT_CYCLES(100)) guard(
 .clk(clk),.rst_n(rst),.frame_valid(fv),.raw_keys(raw),.slow_test(!lesson && !test_mode),.valid(valid),.keys(keys));
 performance_controls #(.EXPANSION(1)) dut(.clk(clk),.rst_n(rst),.frame_valid(valid),.clear(1'b0),
 .remote_valid(1'b0),.remote_keys(8'd0),.keys(keys),.test_mode(test_mode),.test32(test32),.chord_mode(chord),
 .command_count(commands),.last_command(last),.modes(modes),.test_mask(mask),.mask32(masks));
 performance_controls #(.EXPANSION(1)) old(.clk(clk),.rst_n(rst),.frame_valid(fv),.clear(1'b0),
 .remote_valid(1'b0),.remote_keys(8'd0),.keys(raw),.test_mode(legacy_test));
 task frames;input[7:0] k;input integer n;integer i;begin
 for(i=0;i<n;i=i+1)begin @(negedge clk);raw=k;fv=1;@(negedge clk);fv=0;repeat(4)@(negedge clk);end
 end endtask
 task release_keys;begin frames(0,6);end endtask
 integer i;
 initial begin
 repeat(4)@(negedge clk);rst=1;
 frames(16,20);if(test_mode || commands!=0)$fatal(1,"boot stuck T5 accepted");
 if(!legacy_test)$fatal(1,"legacy reproduction absent");
 $display("REPRO legacy enters test from boot-stuck T5; guarded path stays PLAY");
 release_keys();frames(128,6);release_keys();
 frames(16,2);
 if(!legacy_test || test_mode)$fatal(1,"short burst comparison entry failed");
 frames(0,2);frames(16,2);
 if(legacy_test || test_mode)$fatal(1,"short burst comparison exit failed");
 $display("REPRO legacy toggles PLAY -> TEST -> PLAY on two-frame bursts; guarded path stays PLAY");
 release_keys();
 if(test_mode)$fatal(1,"short T5 glitches accepted");
 frames(32,6);if(!chord)$fatal(1,"T6 chord failed");
 frames(16,20);if(test_mode)$fatal(1,"rollover bypassed release");
 release_keys();frames(16,10);if(test_mode)$fatal(1,"T5 early entry");
 frames(16,6);if(!test_mode || !test32)$fatal(1,"deliberate 64-tone test unavailable");
 frames(16,30);if(!test_mode)$fatal(1,"held T5 repeated");
 // Even without a release, emergency T8 escapes.
 frames(128,6);if(test_mode || chord)$fatal(1,"emergency T8 failed");
 release_keys();frames(255,10);frames(16,20);if(test_mode)$fatal(1,"shorted-low/recovery accepted");
 release_keys();frames(1,6);if(modes!=16'h5555)$fatal(1,"normal T1 unavailable");
 release_keys();lesson=1;frames(16,6);if(keys!=16)$fatal(1,"lesson T5 incorrectly long held");
 repeat(120)@(negedge clk);if(keys!=0)$fatal(1,"scanner timeout leaves held key");
 $display("PASS touch guard: startup inhibit, glitches, rollover, sustained 64-tone entry, no-repeat, T8 escape, stuck-low, normal key, lesson short T5, timeout");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
