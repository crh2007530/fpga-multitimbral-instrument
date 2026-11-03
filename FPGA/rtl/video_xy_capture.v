`timescale 1ns/1ps
// Real-time delay portrait: X=PCM[n], Y=PCM[n-16], not stereo phase.
// Capture and normalize a complete block, then publish an immutable bitmap.
// No backpressure to audio. Pixel domain swaps banks only at frame boundaries.
module video_xy_capture(
 input wire sys_clk,sys_rst_n,sample_valid,input wire signed[15:0] pcm,
 input wire pixel_clk,pixel_rst_n,frame_start,input wire[13:0] read_address,
 output reg dot,output reg visible);
 reg signed[15:0] samples[0:1023];
 reg bitmap[0:32767];
 reg[2:0] state;
 localparam CAPTURE=0,CLEAR=1,READ_X=2,LATCH_X=3,READ_Y=4,DRAW=5,WAIT_ACK=6;
 reg[9:0] count,point_index;
 reg[13:0] clear_index;
 reg[15:0] peak;
 reg[3:0] scale_shift;
 reg request,ack;reg[1:0] acks,reqs;
 wire[15:0] absolute=pcm[15] ? -pcm : pcm;
 wire[15:0] final_peak=absolute>peak ? absolute : peak;
 function[3:0] gain_shift;
 input[15:0] value;
 integer i;
 begin gain_shift=0;for(i=0;i<10;i=i+1)if(value>(16'd63<<i))gain_shift=i+1;end
 endfunction
 function[6:0] coordinate;
 input signed[15:0] value;input[3:0] amount;
 reg signed[15:0] scaled;
 begin
  scaled=value>>>amount;
  if(scaled>63)coordinate=127;
  else if(scaled< -63)coordinate=1;
  else coordinate=7'd64+scaled[6:0];
 end
 endfunction
 reg signed[15:0] sample_q;
 reg[6:0] point_x;
 wire[9:0] sample_address=state==READ_Y ? point_index-10'd16 : point_index;
 always @(posedge sys_clk)begin
  if(sys_rst_n && state==CAPTURE && sample_valid)samples[count]<=pcm;
  sample_q<=samples[sample_address];
  if(sys_rst_n && state==CLEAR)bitmap[{~request,clear_index}]<=0;
  if(sys_rst_n && state==DRAW)
   bitmap[{~request,(7'd127-coordinate(sample_q,scale_shift)),point_x}]<=1;
 end
 always @(posedge sys_clk or negedge sys_rst_n)
 if(!sys_rst_n)begin
  state<=CAPTURE;count<=0;point_index<=16;clear_index<=0;
  peak<=0;scale_shift<=0;request<=0;acks<=0;point_x<=0;
 end else begin
  acks<={acks[0],ack};
  case(state)
   CAPTURE:if(sample_valid)begin
    peak<=final_peak;
    if(count==1023)begin scale_shift<=gain_shift(final_peak);clear_index<=0;state<=CLEAR;end
    else count<=count+1'b1;
   end
   CLEAR:if(clear_index==16383)begin point_index<=16;state<=READ_X;end
    else clear_index<=clear_index+1'b1;
   READ_X:state<=LATCH_X;
   LATCH_X:begin point_x<=coordinate(sample_q,scale_shift);state<=READ_Y;end
   READ_Y:state<=DRAW;
   DRAW:if(point_index==1023)begin request<=~request;state<=WAIT_ACK;end
    else begin point_index<=point_index+1'b1;state<=READ_X;end
   WAIT_ACK:if(acks[1]==request)begin count<=0;peak<=0;state<=CAPTURE;end
   default:state<=CAPTURE;
  endcase
 end
 always @(posedge pixel_clk)dot<=bitmap[{ack,read_address}];
 always @(posedge pixel_clk or negedge pixel_rst_n)
 if(!pixel_rst_n)begin reqs<=0;ack<=0;visible<=0;end
 else begin
  reqs<={reqs[0],request};
  if(frame_start && reqs[1]!=ack)begin ack<=reqs[1];visible<=1;end
 end
endmodule
