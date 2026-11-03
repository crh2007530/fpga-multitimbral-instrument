`timescale 1ns/1ps
// Fifteen logarithmic bands for the existing OLED. Raw 1024 complex bins
// remain available at the FFT interface for a future high-resolution display.
module spectrum2048_bars #(parameter integer HOP=512, WINDOW=1)(input wire clk,rst_n,sample_valid,
 input wire signed [15:0] sample_pcm,output wire[31:0] frame_count,missed_windows,output reg [74:0] bars,output reg updated,output wire raw_valid,raw_done,output wire[9:0] raw_bin,output wire signed[23:0] raw_real,raw_imag);
 assign raw_valid=bv;assign raw_done=done;assign raw_bin=bin;assign raw_real=re;assign raw_imag=im;
 wire bv,done,busy;wire [9:0] bin;wire signed [23:0] re,im;wire [31:0] skipped;
 stream_spectrum2048 #(.HOP(HOP),.WINDOW(WINDOW)) transform(.clk(clk),.rst_n(rst_n),.sample_valid(sample_valid),.sample_pcm(sample_pcm),.busy(busy),.bin_valid(bv),.bin_index(bin),.bin_real(re),.bin_imag(im),.frame_done(done),.frame_count(frame_count),.missed_windows(missed_windows));
 wire [23:0] ar=re[23] ? -re : re;
 wire [23:0] ai=im[23] ? -im : im;
 reg [24:0] mag;reg v1,d1,v2,d2,z2;reg [9:0] b1;reg[3:0] band2;reg[4:0] level2;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin mag<=0;v1<=0;d1<=0;v2<=0;d2<=0;z2<=0;b1<=0;band2<=0;level2<=0;end
 else begin
  mag<={1'b0,ar}+{1'b0,ai};v1<=bv;d1<=done;b1<=bin;
  v2<=v1;d2<=d1;z2<=b1==0;band2<=band;level2<=level;
 end
 reg [74:0] pending;
 reg [3:0] band;reg [4:0] level;integer k;
 always @* begin
  if(b1<2)band=0;else if(b1<3)band=1;else if(b1<4)band=2;
  else if(b1<6)band=3;else if(b1<9)band=4;else if(b1<13)band=5;
  else if(b1<19)band=6;else if(b1<28)band=7;else if(b1<42)band=8;
  else if(b1<63)band=9;else if(b1<94)band=10;else if(b1<140)band=11;
  else if(b1<210)band=12;else if(b1<315)band=13;else band=14;
  // Two pixels per magnitude bit above 256, uncalibrated logarithmic level.
  level=0;
  for(k=8;k<24;k=k+1)if(mag[k])level=(k-7)*2-1;
  if(mag[24])level=31;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin pending<=0;bars<=0;updated<=0;end
 else begin
  updated<=0;
  if(v2 && z2)pending<=0;
  else if(v2 && level2>pending[band2*5+:5])pending[band2*5+:5]<=level2;
  if(d2)begin bars<=pending;updated<=1;end
 end
endmodule
