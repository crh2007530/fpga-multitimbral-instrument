`timescale 1ns/1ps
module tb_epiano_envelope;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,ce=0,on=0,off=0,piano=1,flute=0,diag=0;
 wire[15:0] level,legacy;wire active,la;
 instrument_env #(.THIRD_TIMBRE(1)) dut(clk,rst,ce,on,off,flute,diag,level,active,piano);
 adsr_env refenv(clk,rst,ce,on,off,legacy,la,);
 task tick;begin @(negedge clk);ce=1;@(negedge clk);ce=0;end endtask
 task press;begin @(negedge clk);on=1;@(negedge clk);on=0;end endtask
 task release_note;begin @(negedge clk);off=1;@(negedge clk);off=0;end endtask
 integer i;reg[15:0] previous;
 initial begin
 repeat(3)@(negedge clk);rst=1;press;
 repeat(32)tick;if(level!=32767)$fatal(1,"piano attack");
 previous=level;
 for(i=0;i<14000;i=i+1)begin tick;if(level>previous)$fatal(1,"decay wrapped");previous=level;end
 if((level==0 || level>8192)||!active)$fatal(1,"piano sustain");
 release_note;repeat(512)tick;if(level!=0||active)$fatal(1,"piano release");
 press;repeat(16)tick;release_note;repeat(2048)tick;if(active)$fatal(1,"early release");
 press;repeat(32)tick;if(level!=32767)$fatal(1,"retrigger");
 // Timbre is latched for envelope; changing global selector must not corrupt held-note envelope.
 piano=0;flute=1;repeat(14000)tick;if(level==0 || level>8192)$fatal(1,"held envelope changed preset");
 previous=level;repeat(8000)tick;if(level>=previous)$fatal(1,"piano tail failed to decay");repeat(70000)tick;if(active || level!=0)$fatal(1,"held piano must die away");release_note;repeat(512)tick;press;repeat(128)tick;repeat(1024)tick;if(level!=24576)$fatal(1,"flute regression");
 rst=0;repeat(3)@(negedge clk);rst=1;piano=1;diag=1;press;
 for(i=0;i<5000;i=i+1)begin tick;if(level!==legacy||active!==la)$fatal(1,"diagnostic override");end
 release_note;for(i=0;i<4000;i=i+1)begin tick;if(level!==legacy||active!==la)$fatal(1,"diagnostic release");end
 $display("PASS E.PIANO attack/monotone decay/sustain/release/retrigger/held preset and diagnostic bypass");$finish;
 end
endmodule

