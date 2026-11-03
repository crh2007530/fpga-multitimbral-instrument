`timescale 1ns/1ps
module tb_exp4;
reg clk=0;always #5 clk=~clk;reg rst=0,fv=0,testmode=0;reg[7:0]keys=0,pressed=0;
wire active,running,done,wm,beat,exitpulse;wire[1:0]song,tempo;wire[4:0]stepno;
wire[2:0]countin;wire[7:0]hits,misses,wrong,target,nexttarget;wire[47:0]status;
offline_trainer #(.CLOCK_HZ(240)) dut(1'b0,1'b0,8'd0,1'b0,clk,rst,fv,testmode,keys,pressed,active,running,done,wm,song,tempo,stepno,countin,hits,misses,wrong,target,nexttarget,beat,exitpulse,status);
task tick;begin @(negedge clk);end endtask
task frames;input[7:0]k;begin keys=k;fv=1;repeat(4)tick;fv=0;repeat(3)tick;end endtask
task key;input[7:0]k;begin frames(0);frames(k);frames(0);end endtask
task hit;input[7:0]mask;begin pressed=mask;repeat(3)tick;pressed=0;repeat(3)tick;end endtask
integer i,base,oldtimer;
initial begin
 repeat(3)tick;rst=1;
 key(64);if(active)$fatal(1,"short7 entered");
 testmode=1;frames(64);repeat(300)tick;if(active)$fatal(1,"FFT entered training");frames(0);testmode=0;
 frames(64);repeat(250)tick;frames(0);if(!active||running||song!=0||tempo!=1)$fatal(1,"entry");
 key(16);if(!running||countin!=4)$fatal(1,"count in");
 wait(countin==0);tick;if(target!=1)$fatal(1,"first target");
 hit(1);if(hits!=1)$fatal(1,"correct note");
 repeat(10)tick;key(16);oldtimer=dut.timer;repeat(300)tick;
 if(running||dut.timer!=oldtimer)$fatal(1,"pause advanced");key(16);
 wait(stepno==1);tick;
 hit(4);if(wrong!=1)$fatal(1,"wrong pad");
 wait(stepno==2);tick;if(misses!=1)$fatal(1,"miss not counted");
 // Restart and enable waiting mode. A sustained note cannot skip steps.
 key(32);key(8);if(!wm||running)$fatal(1,"wait mode");key(16);wait(countin==0);tick;
 pressed=1;repeat(350)tick;if(stepno!=0||hits!=1)$fatal(1,"held repeated scoring");
 pressed=0;repeat(3)tick;if(stepno!=1)$fatal(1,"wait release");
 hit(4);repeat(300)tick;if(stepno!=1)$fatal(1,"wrong advanced wait");
 hit(2);if(stepno!=2||hits!=2)$fatal(1,"wait correct");
 // Complete scale; final rest advances on its written beat.
 for(i=2;i<15;i=i+1)begin hit(dut.score(song,i));end
 wait(done);if(hits!=15||running||target!=0)$fatal(1,"end of lesson");
 key(2);if(song!=1||done||hits!=0)$fatal(1,"song change");
 key(16);wait(countin==0);tick;
 pressed=1;repeat(2)tick;pressed=5;repeat(2)tick;pressed=21;repeat(2)tick;
 if(hits!=1)$fatal(1,"chord finger skew");pressed=0;repeat(3)tick;
 if(stepno!=1)$fatal(1,"chord release");
 key(128);if(active)$fatal(1,"exit");
 $display("PASS offline trainer: short/long7, FFT lockout, 4-beat count-in, rhythm hit/miss/wrong, pause, wait/release, complete scale, chord finger skew, song selection and exit");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
