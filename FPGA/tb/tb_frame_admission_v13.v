`timescale 1ns/1ps
// Exhaustive phase sweep of the production frame queue + I2S scheduler.
// Does not model physical ADC, PLL jitter or DAC/filter group delay.
module tb_frame_admission_v13;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg[7:0] iv=0;reg[63:0] raw=0;
 wire ct,sc;wire[7:0] ov;wire[63:0] data;
 frame_pressure queue(clk,rst,ct,iv,raw,ov,data);
 i2s_tx tx(.clk(clk),.rst_n(rst),.sample_data(16'd0),.sample_valid(sc),.control_ce(ct),.sample_ce(sc));
 integer cycle=0,phase,launch=0,admit=0,lastct=-1,lastsample=-1,count=0;
 integer delay_cycles,min_delay=999,max_delay=-1,sample_checks=0;
 reg[63:0] expected;
 always @(posedge clk)begin
  cycle=cycle+1;
  if(!rst)begin lastct=-1;lastsample=-1;end
  else begin
   if(ct)begin
    if(lastct>=0 && cycle-lastct!=512)$fatal(1,"control cadence");
    lastct=cycle;
   end
   if(|ov)begin
    if(ov!==8'hff || data!==expected)$fatal(1,"admission data/valid mismatch phase %d",phase);
    admit=cycle;count=count+1;
    delay_cycles=cycle-launch;
    if(delay_cycles<0 || delay_cycles>511)$fatal(1,"queue delay %d",delay_cycles);
    if(delay_cycles<min_delay)min_delay=delay_cycles;
    if(delay_cycles>max_delay)max_delay=delay_cycles;
   end
   if(sc)begin
    if(lastct<0 || cycle-lastct!=8)$fatal(1,"admission to sample spacing");
    if(lastsample>=0 && cycle-lastsample!=512)$fatal(1,"sample cadence");
    lastsample=cycle;sample_checks=sample_checks+1;
   end
  end
 end
 initial begin
  for(phase=0;phase<512;phase=phase+1)begin
   @(negedge clk);rst=0;iv=0;repeat(3)@(negedge clk);rst=1;
   wait(ct);@(posedge clk);@(negedge clk);
   repeat(phase)@(negedge clk);
   expected={8{8'h80 ^ phase[7:0]}};raw=expected;iv=255;launch=cycle+1;
   @(negedge clk);iv=0;
   wait(count==phase+1);wait(sc);@(posedge clk);@(negedge clk);
  end
  if(count!=512 || min_delay!=0 || max_delay!=511 || sample_checks<512)$fatal(1,"coverage");
  $display("PASS all 512 arrival phases: exact 8-pad data, queue delay 0..511 clocks, control->sample always 8 clocks, sample period 512 clocks. This is digital scheduling evidence, NOT zero end-to-end asynchronous jitter.");$finish;
 end
 initial begin #12000000;$fatal(1,"timeout");end
endmodule
