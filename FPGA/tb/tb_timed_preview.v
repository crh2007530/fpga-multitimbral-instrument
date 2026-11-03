`timescale 1ns/1ps
module tb_timed_preview;
reg clk=0,pc=0;always #10 clk=~clk;always #7 pc=~pc;reg rst=0,ready=1;reg[9:0] pos=0;
reg signed[17:0] delta=100;reg[39:0] masks=40'h1008040201;reg[79:0] durations={16'd500,16'd60000,16'd750,16'd250,16'd20};
wire[79:0] deltas;wire[39:0] out_masks;wire out_ready;
timed_chart_preview preview(clk,rst,ready,pos,delta,masks,durations,deltas,out_masks,out_ready);
reg[127:0] game=0;wire hs,vs,de;wire[7:0] r,g,b;
video_dashboard #(.CUSTOM_CHART(0),.TIMED_CHART(1)) screen(.game_data(game),.pixel_clk(pc),.pixel_rst_n(rst),.sys_clk(clk),.sys_rst_n(rst),.fft_valid(1'b0),.fft_done(1'b0),.fft_bin(10'd0),.fft_real(24'd0),.fft_imag(24'd0),.audio_valid(1'b0),.audio_pcm(16'd0),.pressed(8'd0),.target(8'd0),.hs(hs),.vs(vs),.de(de),.red(r),.green(g),.blue(b),.user_chart(256'd0),.chart_enabled(1'b0),.test_mask64(64'd0),.test_selected(6'd0),.timed_enabled(1'b1),.timed_ready(out_ready),.timed_masks(out_masks),.timed_deltas(deltas));
initial begin
repeat(4)@(negedge clk);rst=1;game[30]=1;force screen.frame_start=1;
repeat(100)@(negedge clk);
if(deltas!=={16'd3000,16'd1120,16'd370,16'd120,16'd100})$fatal(1,"prefix/cap %h",deltas);
if(!screen.snapshot[335] || screen.snapshot[334:255]!==deltas || screen.snapshot[183:144]!==masks)$fatal(1,"CDC snapshot");
repeat(10)@(negedge pc);
if(screen.game_view.delta2[3]!==18'sd1120 || screen.game_view.mask3[4]!==8'h10)$fatal(1,"timed raster input");
@(negedge clk);pos=1023;ready=0;delta=-20;masks=40'h0000000080;durations=80'd500;
repeat(20)@(negedge clk);if(out_ready)$fatal(1,"stale tag accepted");
ready=1;repeat(100)@(negedge clk);
if($signed(deltas[15:0])!=-20 || out_masks!=40'h80 || !out_ready)$fatal(1,"negative/end");
if(screen.game_view.delta2[0]!==-18'sd20 || screen.game_view.mask3[1]!=0)$fatal(1,"negative/end raster");
// A bank commit may retain the same position. A ready-low refill must still
// invalidate the old preview; it must not flash the prior bank's notes.
@(negedge clk);ready=0;
repeat(2)@(negedge clk);
masks=40'h0000000042;durations=80'd250;delta=200;ready=1;
if(out_ready)$fatal(1,"same-position stale bank preview");
repeat(8)@(negedge clk);
if(!out_ready || out_masks!=40'h42 || deltas[15:0]!=200)$fatal(1,"same-position replacement");
$display("PASS variable-rhythm prefix timings, long-rest offscreen clamp, coherent CDC, signed late note, end zero masks");$finish;
end
endmodule
