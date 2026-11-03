`timescale 1ns/1ps
module tb_v24_rails;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[10:0]x=0;reg[9:0]y=0;reg[127:0]state=0;wire[23:0]rgb;
video_game_view dut(.clk(clk),.rst_n(rst),.x(x),.y(y),.state(state),.pressed(8'd0),.magnitude(8'd0),.displacement(9'd0),.wave_visible(1'b0),.fft_visible(1'b0),.xy_visible(1'b0),.xy_dot(1'b0),.rgb(rgb),.chart_preview(40'd0),.chart_enabled(1'b0),.timed_enabled(1'b0),.timed_deltas(80'd0));
task pixel;input integer px,py;begin @(negedge clk);x=px;y=py;repeat(2)@(negedge clk);end endtask
task check;input integer px,py;input[23:0]color;begin pixel(px,py);if(rgb!==color)$fatal(1,"rail pixel %d %d got=%h expected=%h",px,py,rgb,color);end endtask
integer row,w;
initial begin repeat(3)@(negedge clk);rst=1;state[30]=1;state[31]=1;
for(row=160;row<608;row=row+1)begin
pixel(0,row);w=8+((row-160)>>3)+((row-160)>>4);
check(590-4*w,row,24'h3378a5);check(593-4*w,row,(row&16)?24'hf6cc63:24'h24415c);
check(598-4*w,row,24'hd6ffff);check(601-4*w,row,24'h16badd);
check(611+4*w,row,24'h16badd);check(616+4*w,row,24'hd6ffff);
check(620+4*w,row,(row&16)?24'hf6cc63:24'h24415c);check(625+4*w,row,24'h3378a5);
end
$display("PASS 448 scanlines symmetric bevel rails and moving stripe palette");$finish;end
endmodule
