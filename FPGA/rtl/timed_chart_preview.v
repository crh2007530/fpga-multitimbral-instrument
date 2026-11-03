`timescale 1ns/1ps
module timed_chart_preview(input clk,rst_n,cache_ready,input[9:0] position,
 input signed[17:0] delta,input[39:0] masks,input[79:0] durations,
 output reg[79:0] deltas,output reg[39:0] out_masks,output ready);
reg[2:0] step;reg[9:0] tag,published_tag;reg published;
reg[79:0] next_deltas;
reg signed[19:0] offset;
assign ready=published && cache_ready && published_tag==position;
always @(posedge clk or negedge rst_n)
if(!rst_n)begin step<=0;tag<=0;published_tag<=0;published<=0;next_deltas<=0;offset<=0;deltas<=0;out_masks<=0;end
else if(!cache_ready || (step!=0 && tag!=position))begin step<=0;published<=0;end
else if(step==0)begin
 if(cache_ready)begin tag<=position;offset<={{2{delta[17]}},delta};step<=1;end
end else if(step<=5)begin
 next_deltas[(step-1)*16+:16]<=offset>3000?16'd3000:offset< -3000?-16'sd3000:offset[15:0];
 // Far future notes are capped; there is no wrap back onto the screen.
 offset<=offset>3000?20'sd3001:offset+$signed({4'd0,durations[(step-1)*16+:16]});
 step<=step+1'b1;
end else begin deltas<=next_deltas;out_masks<=masks;published_tag<=tag;published<=1;step<=0;end
endmodule
