`timescale 1ns/1ps
// All inputs are 3.3V-domain asynchronous inputs. No generated clocks.
// Positive sequence: 00 -> 01 -> 11 -> 10 -> 00. One pulse/full cycle.
// key_n is a SEPARATE verified active-low button input; do not assume C is it.
module encoder_input #(parameter integer FILTER_CYCLES=50000, BUTTON_CYCLES=500000)(
 input wire clk,rst_n,a,b,key_n, output reg inc,dec,click);
 localparam AW=(FILTER_CYCLES<2)?1:$clog2(FILTER_CYCLES);
 localparam KW=(BUTTON_CYCLES<2)?1:$clog2(BUTTON_CYCLES);
 reg [2:0] meta,sync;
 reg [1:0] candidate,stable,prev;
 reg [AW-1:0] count;
 reg key_candidate,key_stable;
 reg [KW-1:0] key_count;
 reg signed [3:0] accum;
 always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
 meta<=3'b001;sync<=3'b001;candidate<=0;stable<=0;prev<=0;
 count<=0;key_candidate<=1;key_stable<=1;key_count<=0;
 accum<=0;inc<=0;dec<=0;click<=0;
 end else begin
 meta<={a,b,key_n};sync<=meta;inc<=0;dec<=0;click<=0;
 if(sync[2:1]!=candidate)begin candidate<=sync[2:1];count<=0;end
 else if(count==FILTER_CYCLES-1)stable<=candidate;
 else count<=count+1'b1;
 if(sync[0]!=key_candidate)begin key_candidate<=sync[0];key_count<=0;end
 else if(key_count==BUTTON_CYCLES-1)begin
 key_stable<=key_candidate;if(key_stable && !key_candidate)click<=1;
 end else key_count<=key_count+1'b1;
 prev<=stable;
 if(prev!=stable)case({prev,stable})
 4'b0001,4'b0111,4'b1110,4'b1000:begin
 if(accum==3)begin inc<=1;accum<=0;end else accum<=accum+1'b1;end
 4'b0010,4'b1011,4'b1101,4'b0100:begin
 if(accum==-3)begin dec<=1;accum<=0;end else accum<=accum-1'b1;end
 default:accum<=0;
 endcase
 end end
endmodule
