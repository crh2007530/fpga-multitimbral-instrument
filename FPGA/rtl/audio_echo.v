`timescale 1ns/1ps
// 8192-frame (~170.5ms) feedback delay. Dry sound is never delayed by
// the delay length. Same three-clock pipeline in bypass and enabled modes.
// Valid-count masks uninitialized BSRAM; no giant RAM reset network.
module audio_echo #(parameter integer ADDR_BITS=13)(
 input wire clk,rst_n,enable,input_valid,
 input wire signed [15:0] input_pcm,
 output reg output_valid,output reg signed [15:0] output_pcm);
 localparam integer DEPTH=1<<ADDR_BITS;
 reg signed [15:0] memory[0:DEPTH-1];
 reg signed [15:0] read_q,dry;
 reg [ADDR_BITS-1:0] pointer,address_d;
 reg [ADDR_BITS:0] filled;
 reg pending,enabled_d,history_valid;
 reg previous_enable;
 wire signed [17:0] feedback=$signed({{2{dry[15]}},dry})+
   (history_valid?($signed({{2{read_q[15]}},read_q})>>>1):18'sd0);
 wire signed [17:0] mixed=$signed({{2{dry[15]}},dry})+
   (history_valid?($signed({{2{read_q[15]}},read_q})>>>2):18'sd0);
 function signed [15:0] saturate;
 input signed [17:0] x;
 begin if(x>32767)saturate=32767;
 else if(x< -32768)saturate=-32768;else saturate=x[15:0];end
 endfunction
 // Read first, write one clock later. Input samples arrive 512 clocks apart.
 always @(posedge clk)begin
   if(input_valid)read_q<=memory[pointer];
   if(pending)memory[address_d]<=enabled_d?saturate(feedback):16'sd0;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   pointer<=0;address_d<=0;filled<=0;pending<=0;dry<=0;
   enabled_d<=0;history_valid<=0;previous_enable<=0;
   output_valid<=0;output_pcm<=0;
 end else begin
   pending<=input_valid;output_valid<=pending;
   if(input_valid)begin
     dry<=input_pcm;address_d<=pointer;pointer<=pointer+1'b1;
     enabled_d<=enable;previous_enable<=enable;
     history_valid<=enable && previous_enable && filled==DEPTH;
     if(!enable || !previous_enable)filled<=enable?1:0;
     else if(filled<DEPTH)filled<=filled+1'b1;
   end
   if(pending)output_pcm<=enabled_d?saturate(mixed):dry;
 end
endmodule
