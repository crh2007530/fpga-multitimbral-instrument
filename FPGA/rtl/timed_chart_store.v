`timescale 1ns/1ps
// Two banks: incomplete uploads never replace the currently playable score.
// Event = duration-to-next-event in ms (16 bits), pressure-pad mask (8 bits).
module timed_chart_store(input clk,rst_n,begin_upload,input[10:0] upload_count,
 input write_event,input[9:0] write_address,input[23:0] write_data,input commit,disable_chart,
 input[9:0] position,output reg enabled,output reg[10:0] count,
 output reg[39:0] masks,output reg[79:0] durations,output wire ready);
reg[23:0] events[0:2047];reg bank;reg[10:0] staged_count;
reg[9:0] captured_position,published_position;reg captured_bank,published_bank,published;
reg[3:0] phase;reg[2:0] slot;reg[23:0] read_q;
wire[10:0] address={1'b0,captured_position}+slot;
always @(posedge clk)begin
 if(write_event)events[{~bank,write_address}]<=write_data;
 read_q<=events[{captured_bank,address[9:0]}];
end
assign ready=enabled && published && published_position==position && published_bank==bank;
always @(posedge clk or negedge rst_n)
if(!rst_n)begin bank<=0;enabled<=0;count<=0;staged_count<=0;phase<=0;slot<=0;captured_position<=0;published_position<=0;captured_bank<=0;published_bank<=0;published<=0;masks<=0;durations<=0;end
else begin
 if(begin_upload)staged_count<=upload_count;
 if(disable_chart)enabled<=0;
 if(commit)begin bank<=~bank;count<=staged_count;enabled<=1;published<=0;phase<=0;end
 else case(phase)
 // Cache only changes when its position or bank changes. Outputs are invalid
 // during refill; consumers use ready, so a second 120-bit cache is needless.
 0:if(!ready)begin published<=0;captured_position<=position;captured_bank<=bank;slot<=0;phase<=1;end
 1:phase<=2;
 2:begin
 masks[slot*8+:8]<=address<count?read_q[7:0]:8'd0;
 durations[slot*16+:16]<=address<count?read_q[23:8]:16'd0;
 if(slot==4)phase<=3;else begin slot<=slot+1'b1;phase<=1;end
 end
 3:begin published_position<=captured_position;published_bank<=captured_bank;published<=1;phase<=0;end
 default:phase<=0;
 endcase
end
endmodule

