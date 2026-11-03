`timescale 1ns/1ps
// Capture 1024 consecutive audio samples. Freeze published RAM until video
// acknowledges at a frame boundary; capture never stalls the audio engine.
module video_wave_capture(input wire sys_clk,sys_rst_n,sample_valid,
 input wire signed[15:0] pcm,input wire pixel_clk,pixel_rst_n,frame_start,
 input wire[9:0] read_index,output wire signed[8:0] displacement,output reg visible);
 reg[15:0] memory[0:2047];
 reg[9:0] index;reg request,ack;reg[1:0] acks,reqs;
 reg[15:0] peak,published_peak;reg[3:0] shift;
 wire[15:0] abs_pcm=pcm[15]?-pcm:pcm;
 wire[15:0] next_peak=index==0 ? abs_pcm : abs_pcm>peak ? abs_pcm : peak;
 always @(posedge sys_clk)
 if(sys_rst_n && sample_valid && request==acks[1])memory[{~request,index}]<=pcm;
 always @(posedge sys_clk or negedge sys_rst_n)
 if(!sys_rst_n)begin index<=0;request<=0;acks<=0;peak<=0;published_peak<=0;end
 else begin
  acks<={acks[0],ack};
  if(sample_valid && request==acks[1])begin
   peak<=next_peak;index<=index+1'b1;
   if(index==1023)begin published_peak<=next_peak;request<=~request;end
  end
 end
 always @(posedge pixel_clk or negedge pixel_rst_n)
 if(!pixel_rst_n)begin ack<=0;reqs<=0;shift<=0;visible<=0;end
 else begin
  reqs<={reqs[0],request};
  if(frame_start && reqs[1]!=ack)begin
   ack<=reqs[1];visible<=1;
   if(published_peak>24576)shift<=9;else if(published_peak>12288)shift<=8;
   else if(published_peak>6144)shift<=7;else if(published_peak>3072)shift<=6;
   else if(published_peak>1536)shift<=5;else if(published_peak>768)shift<=4;
   else if(published_peak>384)shift<=3;else if(published_peak>192)shift<=2;
   else if(published_peak>96)shift<=1;else shift<=0;
  end
 end
 reg signed[15:0] read_q;
 always @(posedge pixel_clk)read_q<=memory[{ack,read_index}];
 wire signed[15:0] scaled=read_q>>>shift;
 assign displacement=!visible ? 9'sd0 : scaled>96 ? 9'sd96 : scaled< -96 ? -9'sd96 : scaled[8:0];
endmodule
