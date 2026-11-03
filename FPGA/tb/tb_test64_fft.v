`timescale 1ns/1ps
module tb_test64_fft;
reg clk=0;always #5 clk=~clk;reg rst=0,sv=0;reg signed[15:0]pcm=0;
wire busy,bv,done;wire[9:0]bin;wire signed[23:0]re,im;wire[31:0]frames,missed;
stream_spectrum2048 #(.HOP(2048),.WINDOW(1)) dut(clk,rst,sv,pcm,busy,bv,bin,re,im,done,frames,missed);
integer f,o,i,n,rc,value;integer bin_count=0;
always @(negedge clk)if(bv)begin $fdisplay(o,"%d %d %d",bin,$signed(re),$signed(im));bin_count=bin_count+1;end
initial begin
repeat(4)@(negedge clk);rst=1;
for(n=0;n<2;n=n+1)begin
 if(n==0)begin f=$fopen("checks/pcm64_actual.txt","r");o=$fopen("checks/fft64_all.txt","w");end
 else begin f=$fopen("checks/pcm64_muted.txt","r");o=$fopen("checks/fft64_muted.txt","w");end
 bin_count=0;
 for(i=0;i<2048;i=i+1)begin
  rc=$fscanf(f,"%d",value);if(rc!=1)$fatal(1,"PCM input incomplete");
  @(negedge clk);sv=1;pcm=value;@(negedge clk);sv=0;repeat(62)@(negedge clk);
 end
 wait(done);repeat(4)@(negedge clk);$fclose(f);$fclose(o);
 if(bin_count!=1024 || missed!=0)$fatal(1,"FFT frame incomplete");
end
$display("PASS production Hann + FFT RTL transforms actual64-voice PCM and voice32 mute, all1024 bin_count, no missed frames");$finish;
end
initial begin #20000000;$fatal(1,"FFT timeout");end
endmodule

