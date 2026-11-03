`timescale 1ns/1ps
`include "tb/pcf8591_model.v"
module tb_exp3_adc;
reg clk=0;always #10 clk=~clk;reg rst=0;tri1 scl,sda;
wire[31:0] raw,transactions,time_us,scans;wire[3:0] valid;wire[127:0]stamps;wire[15:0]errors;wire overdue;
timebase_us #(.CLOCK_HZ(50000000)) timer(clk,rst,time_us);
pcf8591_model model(scl,sda,1'b1,32'h80706050,transactions);
pcf8591_scan #(.SCAN_CYCLES(75000),.QUARTER_CYCLES(125),.TIMEOUT_CYCLES(50000)) dut(
 .clk(clk),.rst_n(rst),.time_us(time_us),.scl(scl),.sda(sda),.raw(raw),.raw_valid(valid),
 .sampled_at(stamps),.scans(scans),.errors(errors),.overdue(overdue));
integer cycle=0,last[0:3],count[0:3],i,maxage=0;
always @(posedge clk)if(rst)begin
 cycle=cycle+1;
 for(i=0;i<4;i=i+1)if(valid[i])begin
  if(count[i]>0 && cycle-last[i]!=75000)$fatal(1,"scan jitter ch%0d",i);
  last[i]=cycle;count[i]=count[i]+1;
  if(time_us-stamps[i*32+:32]>maxage)maxage=time_us-stamps[i*32+:32];
  if(time_us-stamps[i*32+:32]>185)$fatal(1,"conversion age");
 end
 if(scans==5)begin
  if(raw!==32'h80706050 || errors || overdue)$fatal(1,"scan failure");
  for(i=0;i<4;i=i+1)if(count[i]!=5)$fatal(1,"missing result");
  $display("PASS wire-level PCF8591: 5 scans x4 channels, exact 75000-clock cadence, max timestamp age=%0d us, no errors/overdue",maxage);$finish;
 end
end
initial begin for(i=0;i<4;i=i+1)begin last[i]=0;count[i]=0;end #100;rst=1;#10000000;$fatal(1,"timeout");end
endmodule
