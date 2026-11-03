`timescale 1ns/1ps
// Testbench-only idle-clock compression: 16 active clocks/sample, then a time gap.
// No FPGA RTL parameters changed. Not a full-rate clock or I2S throughput test.
module tb_v30_3_fx_soak;
reg clk=0,rst=0,valid=0,bypass=0,testmode=0;
reg signed[15:0] pcm=0;
reg[32:0]cfg={2'd0,2'd0,5'd8,3'd4,2'd0,5'd8,2'd1,2'd1,5'd8,5'd16};
reg[2:0]en=0;wire ov;wire signed[15:0]out;
integer n,count=0,age=0,expected=0,nonzero=0,clipped=0,sec=0,wraps=0;
integer prev_ptr=0;reg verify=0;reg[31:0]noise=32'h12345678;
audio_send_fx dut(clk,rst,valid,pcm,cfg,en,bypass,testmode,ov,out);
always @(posedge clk)begin
 if(valid)age=0;else age=age+1;
 #1;
 if(rst && ov)begin
  if(age!=8)$fatal(1,"latency changed %0d sample=%0d",age,n);
  count=count+1;
  if(^out===1'bx)$fatal(1,"unknown PCM sample=%0d",n);
  if(verify && out!==expected)$fatal(1,"dry/test mismatch sample=%0d",n);
  if(out!=0)nonzero=nonzero+1;
  if(out==32767 || out==-32768)clipped=clipped+1;
 end
end
task cycle;begin #5;clk=1;#5;clk=0;end endtask
task sample;input integer value;begin
 pcm=value;expected=value;valid=1;cycle;valid=0;repeat(15)cycle;
 if(count!=n+1)$fatal(1,"lost/duplicate output n=%0d count=%0d",n,count);
 if(dut.echo.pointer<prev_ptr)wraps=wraps+1;prev_ptr=dut.echo.pointer;
 #20653;
end endtask
initial begin
 repeat(4)cycle;rst=1;
 // 1,441,407 samples / (24.6 MHz / 512) = 30.0000156 seconds audio.
 for(n=0;n<1441407;n=n+1)begin
  if(n%48047==0)begin
   sec=n/48047;
   $display("PROGRESS audio_second=%0d samples=%0d time_ns=%0t",sec,n,$time);$fflush();
   cfg[4:0]=16;cfg[9:5]=16;cfg[18:14]=8;cfg[28:24]=8;
   cfg[13:12]=sec%3;cfg[11:10]=(sec/3)%3;
   cfg[20:19]=sec%3;cfg[23:21]=sec%7;
   cfg[30:29]=(sec/2)%3;cfg[32:31]=(sec/3)%3;
   en=sec==0?0:7;bypass=sec==12 || sec==13;testmode=sec>=27;
  end
  verify=sec==0 || testmode;
  noise={noise[30:0],noise[31]^noise[21]^noise[1]^noise[0]};
  sample(testmode?0:(n%48047<24000 ? $signed(noise[15:0])/4:0));
 end
 if(nonzero<100000 || wraps<100)$fatal(1,"coverage nonzero=%0d wraps=%0d",nonzero,wraps);
 $display("PASS continuous FX samples=%0d nonzero=%0d clipped=%0d echo_wraps=%0d no reset; preset/gain/bypass/test switches; fixed 8-cycle latency; no X, loss or duplicates",count,nonzero,clipped,wraps);
 $display("MEASURE simulator_time_ns=%0t audio_seconds=30.0000156 active_clocks_per_sample=16 production_clocks_per_sample=512",$time);$finish;
end
endmodule
