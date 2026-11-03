`timescale 1ns/1ps
// 48046.875/6 = 8007.8125 samples/s, unsigned 8-bit mono.
// Packet: A5 5A, seq LE16, length(0..64), flags(bit0=end), dropped LE32,
// payload, additive checksum such that sum(all bytes after sync)==0 mod256.
// Continuous streaming is separate from the original short-clip recorder.
module pcm_uart_stream #(parameter ADDR_BITS=11)(input clk,rst_n,start,stop,
 input sample_valid,input signed[15:0] pcm,input pause_new,
 output reg tx_valid,output reg[7:0] tx_data,input tx_ready,
 output wire packet_active,output reg recording,output reg[31:0] dropped,output wire busy);
 localparam CAPACITY=1<<ADDR_BITS;
 reg[7:0] fifo[0:CAPACITY-1];reg[ADDR_BITS-1:0] wr,rd;
 reg[ADDR_BITS:0] used;reg[2:0] decimate;
 reg pending_end;reg[15:0] sequence_id;reg[7:0] sum;
 reg[3:0] state;reg[6:0] length,index;reg[31:0] report_drop;reg end_packet;
 reg[7:0] read_q;
 reg signed[18:0] accumulator;
 wire signed[18:0] total=accumulator+{{3{pcm[15]}},pcm};
 wire signed[18:0] average=total/19'sd6;
 wire enqueue=recording && sample_valid && decimate==5 && !stop;
 wire pop=state==12 && tx_ready;
 wire push=enqueue && (used<CAPACITY || pop);
 assign packet_active=state!=0;
 assign busy=recording || pending_end || state!=0;
 always @(posedge clk)begin
  if(push)fifo[wr]<=average[15:8]^8'h80;
  read_q<=fifo[rd];
 end
 always @*begin
 tx_valid=state!=0 && state!=11;tx_data=0;
 case(state)
  1:tx_data=8'ha5;2:tx_data=8'h5a;3:tx_data=sequence_id[7:0];4:tx_data=sequence_id[15:8];
  5:tx_data={1'b0,length};6:tx_data={7'd0,end_packet};
  7:tx_data=report_drop[7:0];8:tx_data=report_drop[15:8];9:tx_data=report_drop[23:16];10:tx_data=report_drop[31:24];
  12:tx_data=read_q;13:tx_data=-sum;
  default:;
 endcase
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin wr<=0;rd<=0;used<=0;decimate<=0;accumulator<=0;pending_end<=0;sequence_id<=0;sum<=0;state<=0;length<=0;index<=0;report_drop<=0;end_packet<=0;recording<=0;dropped<=0;end
 else if(start && !recording && !pending_end && state==0)begin
  wr<=0;rd<=0;used<=0;decimate<=0;accumulator<=0;sequence_id<=0;recording<=1;dropped<=0;
 end else begin
  if(stop && recording)begin recording<=0;pending_end<=1;end
  if(recording && sample_valid)begin
   decimate <= (decimate == 3'd5) ? 3'd0 : decimate + 3'd1;
   accumulator<=decimate==5?19'sd0:total;
  end
  if(enqueue && !push)dropped<=dropped+1'b1;
  if(push)wr<=wr+1'b1;
  if(pop)rd<=rd+1'b1;
  case({push,pop})2'b10:used<=used+1'b1;2'b01:used<=used-1'b1;default:;endcase
  if(state==0)begin
   if(!pause_new && (used>=64 || pending_end))begin
    length<=used>=64?7'd64:used[6:0];end_packet<=pending_end && used<=64;
    report_drop<=dropped;sum<=0;index<=0;state<=1;
   end
  end else if(state==11)state<=12;
  else if(tx_ready)begin
   if(state>=3 && state<=12)sum<=sum+tx_data;
   if(state==10)state<=length==0?13:11;
   else if(state==12)begin if(index+1==length)state<=13;else begin index<=index+1'b1;state<=11;end end
   else if(state==13)begin state<=0;sequence_id<=sequence_id+1'b1;if(end_packet)pending_end<=0;end
   else state<=state+1'b1;
  end
 end
endmodule
