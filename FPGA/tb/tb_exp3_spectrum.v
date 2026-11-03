`timescale 1ns/1ps
module tb_exp3_spectrum;
reg clk=0;always #10 clk=~clk;reg rst=0,sv=0;reg signed[15:0] pcm=0;
wire[74:0]bars;wire updated;
audio_spectrum dut(clk,rst,sv,pcm,bars,updated);
integer n,j,i,peak,updates=0;real x;
always @(posedge updated)updates=updates+1;
task sample;input integer value;
begin @(negedge clk);sv=1;pcm=value;@(negedge clk);sv=0;repeat(199)@(negedge clk);end endtask
initial begin
 repeat(4)@(negedge clk);rst=1;
 // Fs/8 bin 3: 563.05 Hz nominal. Bin 5 has half amplitude.
 for(n=0;n<32;n=n+1)begin
  x=1024*$sin(6.283185307179586*3*n/32)+512*$sin(6.283185307179586*5*n/32);
  for(j=0;j<8;j=j+1)sample($rtoi(x));
 end
 wait(updated);#1;
 if(bars[2*5+:5]<14 || bars[4*5+:5]<6)$fatal(1,"missing bin3/bin5 peaks %h",bars);
 for(i=0;i<15;i=i+1)if(i!=2 && i!=4 && bars[i*5+:5]>1)$fatal(1,"spurious bin %0d",i+1);
 for(n=0;n<256;n=n+1)sample(0);
 wait(updated);#1;if(bars!==0)$fatal(1,"stale spectrum on silence");
 $display("PASS real HDL 32-point DFT: bin3/bin5 two-tone peaks, other bins quiet, next silence clears all bins; updates=%0d",updates);$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
