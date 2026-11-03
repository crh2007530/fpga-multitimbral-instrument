`timescale 1ns/1ps
module tb_exp4_tempo;
reg clk=0;always #5 clk=~clk;reg rst=0,fv=0;reg[7:0]keys=0,pressed=0;
wire active,running,done,wm,beat,exitpulse;wire[1:0]song,tempo;wire[4:0]stepno;
wire[2:0]countin;wire[7:0]hits,misses,wrong,target,nexttarget;wire[47:0]status;
offline_trainer #(.CLOCK_HZ(240)) dut(1'b0,1'b0,8'd0,1'b0,clk,rst,fv,1'b0,keys,pressed,active,running,done,wm,song,tempo,stepno,countin,hits,misses,wrong,target,nexttarget,beat,exitpulse,status);
task tick;begin @(negedge clk);end endtask
task frames;input[7:0]k;begin keys=k;fv=1;repeat(4)tick;fv=0;repeat(3)tick;end endtask
task key;input[7:0]k;begin frames(0);frames(k);frames(0);end endtask
integer cycles=0,start,n,b,expected_misses;
always @(posedge clk)cycles=cycles+1;
initial begin
 repeat(3)tick;rst=1;frames(64);repeat(250)tick;frames(0);
 // All three scores at each supported tempo; no presses means only written notes miss.
 for(n=0;n<9;n=n+1)begin
  key(16);wait(countin==0);#1;start=cycles;
  b=tempo==0?240:tempo==1?160:120;
  expected_misses=song==0?15:song==1?12:11;
  wait(done);#1;
  if(cycles-start!=b*(song==2?18:16))$fatal(1,"score duration song=%d tempo=%d cycles=%d",song,tempo,cycles-start);
  if(misses!=expected_misses||hits!=0||wrong!=0)$fatal(1,"rest counted as missed note");
  if(n%3==2)key(2);key(4);
 end
 // A late correct key must not receive rhythm credit.
 key(16);wait(countin==0);tick;b=tempo==0?240:tempo==1?160:120;
 repeat(b/4+1)tick;pressed=1;repeat(3)tick;pressed=0;
 wait(stepno==1);tick;if(hits!=0||misses!=1)$fatal(1,"late note credited");
 $display("PASS 3 scores x 3 tempos: exact whole-score beat counts, timed rests/double beats, unattended miss counts, late hit excluded");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
