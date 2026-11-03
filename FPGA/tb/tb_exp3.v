`timescale 1ns/1ps
module tb_exp3;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0;reg[7:0] valid=0;reg[63:0] raw=0;
wire[7:0] ov;wire[63:0] od;
frame_pressure q(clk,rst,ce,valid,raw,ov,od);
reg sv=0;reg signed[15:0] pcm=0;wire[319:0] pts;
audio_waveform w(clk,rst,sv,pcm,pts);
integer i,j;
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
initial begin
 tick;rst=1;tick;
 for(i=0;i<512;i=i+1)begin
  for(j=0;j<512;j=j+1)begin
   ce=(j==511);valid=(j==i)?8'hff:0;raw={8{8'(i)}};#1;
   if(ov !== (ce?8'hff:8'h00))$fatal(1,"phase %0d valid",i);
   if(ce && od !== {8{8'(i)}})$fatal(1,"phase %0d data",i);
   tick;
  end
  ce=1;valid=0;#1;if(ov!==0)$fatal(1,"duplicate");tick;ce=0;
 end
 valid=1;raw=64'd12;tick;raw=64'd80;tick;valid=0;ce=1;#1;
 if(od[7:0]!=80 || ov!=1)$fatal(1,"latest wins");tick;ce=0;
 pcm=32767;sv=1;repeat(8)tick;
 if(pts[319:315]!=1)$fatal(1,"positive clip");
 pcm=-32768;repeat(8)tick;
 if(pts[319:315]!=31 || pts[314:310]!=1)$fatal(1,"negative clip/order");
 pcm=0;repeat(512)tick;
 if(pts!=={64{5'd16}})$fatal(1,"silence");
 $display("PASS all 512 arrival phases x8 pads, same-edge arrival, exactly-once commit, latest wins; waveform decimation/clipping/silence");$finish;
end
endmodule
