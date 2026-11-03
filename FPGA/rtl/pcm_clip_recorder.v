`timescale 1ns/1ps
// Post-synthesis PCM clip. Four-sample box average -> unsigned 8-bit PCM.
// 32768 bytes at 48046.875/4 Hz = 2.728 seconds, then stop (never wrap).
module pcm_clip_recorder #(parameter ADDR_BITS=15)(
 input clk,rst_n,start,stop,sample_valid,input signed[15:0] pcm,
 output reg recording,ready,output reg[15:0] count,
 input[14:0] read_address,output reg[7:0] read_data);
 localparam integer CAPACITY=1<<ADDR_BITS;
 reg[7:0] memory[0:CAPACITY-1];reg[1:0] phase;reg signed[17:0] accumulator;
 wire signed[17:0] total=accumulator+{{2{pcm[15]}},pcm};
 wire[7:0] quantized=total[17:10]^8'h80;
 always @(posedge clk)begin
  read_data<=memory[read_address[ADDR_BITS-1:0]];
  if(recording && sample_valid && phase==3 && !stop && !start)
   memory[count[ADDR_BITS-1:0]]<=quantized;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin recording<=0;ready<=0;count<=0;phase<=0;accumulator<=0;end
 else if(start)begin recording<=1;ready<=0;count<=0;phase<=0;accumulator<=0;end
 else if(stop)begin recording<=0;ready<=count!=0;phase<=0;accumulator<=0;end
 else if(recording && sample_valid)begin
  if(phase==3)begin
   phase<=0;accumulator<=0;count<=count+1'b1;
   if(count==CAPACITY-1)begin recording<=0;ready<=1;end
  end else begin phase<=phase+1'b1;accumulator<=total;end
 end
endmodule
