`timescale 1ns/1ps
module tb_v22_palette;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[10:0]x=0;reg[9:0]y=0;reg[127:0]s=0;reg[7:0]keys=0;wire[23:0]rgb,old_rgb;
video_game_view dut(clk,rst,x,y,s,keys,8'd80,9'sd35,1'b1,1'b1,1'b1,1'b0,rgb,40'd0,1'b0,1'b0,80'd0);
game_rgb_reference reference(clk,rst,x,y,s,keys,8'd80,9'sd35,1'b1,1'b1,1'b1,1'b0,old_rgb,40'd0,1'b0,1'b0,80'd0);
integer i;reg[23:0]expected;
initial begin repeat(4)@(negedge clk);rst=1;end
initial begin
wait(rst);s[30]=1;s[31]=1;
for(i=0;i<16000;i=i+1)begin
@(negedge clk);x=0;y=$urandom_range(0,719);s[15:0]=$urandom_range(0,16000);s[21:16]=$urandom_range(0,31);keys=$random;
repeat(5)@(negedge clk);x=$urandom_range(0,1279);
@(posedge clk);#1;expected=old_rgb==24'hf0fbff ? 24'he5f4ff : old_rgb;
if(rgb!==expected)$fatal(1,"palette mismatch x=%d y=%d new=%h ref=%h",x,y,rgb,old_rgb);
end
$display("PASS 16000 randomized pixels shared-palette equivalence; two near-white highlights intentionally unified");$finish;end
endmodule

`timescale 1ns/1ps
module game_rgb_reference #(parameter CUSTOM_CHART=0,TIMED_CHART=0)(input wire clk,rst_n,input wire[10:0] x,input wire[9:0] y,
 input wire[127:0] state,input wire[7:0] pressed,magnitude,
 input wire signed[8:0] displacement,input wire wave_visible,fft_visible,xy_visible,xy_dot,
 output reg[23:0] rgb,input[39:0] chart_preview,input chart_enabled,input timed_enabled,input[79:0] timed_deltas);
 `include "rtl/rhythm_chart.vh"
 wire timed=TIMED_CHART && timed_enabled;wire[15:0] time_ms=state[15:0];wire[5:0] position=state[21:16];
 // Compute chart positions outside the per-pixel color path. All stages settle
 // in the first blank header row after the frame-atomic state update.
 reg signed[17:0] due1[0:4],delta2[0:4],bottom3[0:4],top3[0:4];
 reg[7:0] mask1[0:4],mask2[0:4],mask3[0:4];
 reg chord3[0:4];
 genvar q;
 generate for(q=0;q<5;q=q+1)begin:positions
 localparam [5:0] STEP=q,LAST=41-q;
 wire[5:0] beats=chart_beat(position+STEP);
 wire signed[17:0] standard_due=$signed({12'd0,beats})*18'sd500;
 wire[1:0] speed=state[103:102];
 wire signed[17:0] fall_delta=timed?delta2[q]>>>2:speed==0?delta2[q]>>>3:speed==2?delta2[q]>>>1:delta2[q]>>>2;
 localparam signed[17:0] OFFSET=2000+q*500;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  due1[q]<=0;delta2[q]<=0;bottom3[q]<=0;top3[q]<=0;mask1[q]<=0;mask2[q]<=0;mask3[q]<=0;chord3[q]<=0;
 end else begin
   due1[q]<=(CUSTOM_CHART && chart_enabled)?OFFSET+$signed({12'd0,position})*18'sd500:18'sd2000+(speed==0?standard_due<<<1:speed==2?standard_due>>>1:standard_due);
   mask1[q]<=timed?chart_preview[q*8+:8]:position<=((CUSTOM_CHART && chart_enabled)?31-q:LAST)?(CUSTOM_CHART && chart_enabled ? chart_preview[q*8+:8] : chart(position+STEP)):8'd0;
   if(q==0)mask1[q]<=((timed || CUSTOM_CHART && chart_enabled) ? chart_preview[7:0] : chart(position))&~state[29:22];
   delta2[q]<=timed?$signed(timed_deltas[q*16+:16]):due1[q]-$signed({2'b0,time_ms});mask2[q]<=mask1[q];
   bottom3[q]<=18'sd608-fall_delta;top3[q]<=18'sd596-fall_delta;mask3[q]<=mask2[q];
   chord3[q]<=(mask2[q] & (mask2[q]-8'd1))!=0;
 end
 end endgenerate

 // Visual feedback is frame-paced and never feeds audio or score logic.
 // A new correct hit is identified by the authoritative score counters,
 // including chord fingers hit on adjacent frames. A held key cannot retrigger.
 reg[3:0] hit_age[0:7];reg[7:0] last_pressed,last_hit;
 reg[15:0] last_points;reg[3:0] judge_age;reg[2:0] last_judge;
 integer h;
 wire feedback_tick=x==0 && y==1;
 wire[7:0] fresh_hits=state[29:22] & ~last_hit;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin last_pressed<=0;last_hit<=0;last_points<=0;judge_age<=0;last_judge<=0;
 for(h=0;h<8;h=h+1)hit_age[h]<=0;end
 else if(feedback_tick)begin
 last_pressed<=pressed;last_hit<=state[29:22];last_points<=state[51:36];last_judge<=state[35:33];
 if(!state[30] || !state[31])begin judge_age<=0;for(h=0;h<8;h=h+1)hit_age[h]<=0;end
 else begin
 if(state[35:33]!=0 && (state[35:33]!=last_judge || state[51:36]!=last_points))judge_age<=12;
 else if(judge_age!=0)judge_age<=judge_age-1'b1;
 for(h=0;h<8;h=h+1)begin
 if(state[51:36]!=last_points && (state[35:33]==1 || state[35:33]==2) &&
 (fresh_hits[h] || (pressed[h] && !last_pressed[h])))hit_age[h]<=10;
 else if(hit_age[h]!=0)hit_age[h]<=hit_age[h]-1'b1;
 end
 end
 end
 function[23:0] lane_color;input integer id;begin case(id)
 0:lane_color=24'hff5c88;1:lane_color=24'hffb454;
 2:lane_color=24'hf2df68;3:lane_color=24'h5be0a0;
 4:lane_color=24'h47d9ff;5:lane_color=24'h648bff;
 6:lane_color=24'hb18aff;default:lane_color=24'hf280da;
 endcase end endfunction
 // One geometry update per scanline; no framebuffer, divider or multiplier IP.
 reg[10:0] edge_x[0:8];reg[7:0] row_notes,row_chords;
 reg[7:0] next_notes,next_chords;integer j,k;
 wire[10:0] lane_width=11'd16+{4'd0,y[9:3]};
 always @*begin
 next_notes=0;next_chords=0;
 for(j=0;j<5;j=j+1)begin
 if($signed({8'd0,y})>=top3[j] && $signed({8'd0,y})<bottom3[j])begin
 next_notes=next_notes|mask3[j];if(chord3[j])next_chords=next_chords|mask3[j];end
 end end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin row_notes<=0;row_chords<=0;for(k=0;k<9;k=k+1)edge_x[k]<=0;end
 else if(x==0)begin
 row_notes<=next_notes;row_chords<=next_chords;
 edge_x[0]<=11'd608 - (lane_width<<2);
edge_x[1]<=11'd608 - ((lane_width<<1)+lane_width);
edge_x[2]<=11'd608 - (lane_width<<1);
edge_x[3]<=11'd608 - lane_width;
edge_x[4]<=11'd608 + 11'd0;
edge_x[5]<=11'd608 + lane_width;
edge_x[6]<=11'd608 + (lane_width<<1);
edge_x[7]<=11'd608 + ((lane_width<<1)+lane_width);
edge_x[8]<=11'd608 + (lane_width<<2);
 end
 wire[9:0] motion_y=y+{4'd0,time_ms[8:3]};
 wire[10:0] ship_dx=x>=608?x-11'd608:11'd608-x;
 wire[9:0] ship_width=(y-10'd548)>>1;
 wire[10:0] gate_dx=x>=608?x-11'd608:11'd608-x;
 wire[9:0] gate_dy=y>=168?y-10'd168:10'd168-y;
 wire[10:0] gate_radius=11'd30+{6'd0,time_ms[9:5]};
 // Independent layers are registered before compositing. Lane windows are
 // disjoint, so their colors combine with OR rather than eight priority muxes.
 reg[23:0] base_c,overlay_c,base_q,overlay_q;
 reg overlay_hit,overlay_hit_q;
 reg gate_hit_q;
 wire gate_hit=y>=100 && y<240 && gate_distance>={1'b0,gate_radius} && gate_distance<({1'b0,gate_radius}+12'd3);
 reg[23:0] lane_c[0:7],lane_q[0:7];reg[7:0] lane_hit,lane_hit_q;
 integer lane;reg signed[10:0] wave_y;reg[23:0] accent;
 wire[11:0] gate_distance={1'b0,gate_dx}+{2'd0,gate_dy};
 wire[11:0] progress_end=state[32]?12'd1000:12'd32+{6'd0,position}*12'd23;
 always @*begin
 base_c={8'h05,8'h09,{3'b000, y[9:5]}};overlay_c=0;overlay_hit=0;
 wave_y=11'sd176-($signed({{2{displacement[8]}},displacement})>>>1);
 if(x>208 && x<1016 && y>96 && y<608 &&
 ((x[6:0]^{1'b0,y[5:0]})==7'd43) && motion_y[5:0]==6'd7)base_c=24'h54749c;
 if(x>=32 && x<1000 && y>=56 && y<60)base_c=24'h193d58;
 if(!timed && x>=32 && x<progress_end && x<1000 && y>=56 && y<60)base_c=24'h35d9f0;
 if(y<52)base_c=24'h16263e;
 if(x>=16 && x<208 && y>=96 && y<680)base_c=24'h101d32;
 if(x>=1016 && x<1264 && y>=96 && y<680)base_c=24'h101d32;
 // Gate is an independent registered mask, composed before lane overlays.
 for(lane=0;lane<8;lane=lane+1)begin
 lane_hit[lane]=0;lane_c[lane]=0;
 accent=lane_color(lane);
 if(y>=200 && y<608 && x>=edge_x[lane] && x<edge_x[lane+1])begin
 lane_hit[lane]=1;lane_c[lane]=lane[0]?24'h10213a:24'h0c1628;
 if(motion_y[5:0]<2)lane_c[lane]=24'h214266;
 if(x<edge_x[lane]+11'd2)lane_c[lane]=24'h3975a0;
 if(pressed[lane] && y>=488)lane_c[lane]={2'b00,accent[23:18],2'b00,accent[15:10],2'b00,accent[7:2]};
 if(hit_age[lane]!=0 && y>=10'd608-{3'd0,hit_age[lane],3'b000})
 lane_c[lane]={1'b0,accent[23:17],1'b0,accent[15:9],1'b0,accent[7:1]};
 if(row_notes[lane] && x>=edge_x[lane]+11'd4 && x<edge_x[lane+1]-11'd4)
 begin
 lane_c[lane]=row_chords[lane]?24'hffcb68:accent;
 // Bevels and inner light make note blocks readable without texture RAM.
 if(x<edge_x[lane]+11'd7 || x>=edge_x[lane+1]-11'd7)lane_c[lane]=24'he5f4ff;
 end
 if(pressed[lane] && y>=592 && (x<edge_x[lane]+11'd5 || x>=edge_x[lane+1]-11'd5))lane_c[lane]=accent;
 end
 if(y>=624 && y<680 && x>=224+lane*96 && x<320+lane*96)begin
 lane_hit[lane]=1;lane_c[lane]=pressed[lane]?accent:24'h142139;
 if(y>=672 || y<628)lane_c[lane]=accent;
 if(hit_age[lane]!=0 && (y<632 || y>=668))lane_c[lane]=24'hf0fbff;
 if(x==224+lane*96 || x==319+lane*96)lane_c[lane]=24'h080f21;
 end
 end
 if(judge_age!=0 && x>=400 && x<816 && y>=76 && y<100)begin
 overlay_hit=1;overlay_c=(state[35:33]==1)?24'h156756:(state[35:33]==2)?24'h245c83:24'h702f4c;
 end
 if(x>=224 && x<992 && y>=612 && y<620)begin overlay_hit=1;overlay_c=24'h164b61;end
 if(x>=224 && x<992 && y>=608 && y<612)begin overlay_hit=1;overlay_c=24'hd5fff7;end
 if(y>=548 && y<580 && ship_dx<=ship_width)begin overlay_hit=1;overlay_c=24'hc4deef;end
 if(y>=556 && y<580 && ship_dx<3)begin overlay_hit=1;overlay_c=24'h35d9f0;end
 if(y>=580 && y<10'd586+{6'd0,state[109:106]} && (ship_dx==5 || ship_dx==6))begin overlay_hit=1;overlay_c=24'h29d9ff;end
 if(x>=1040 && x<1240 && y>=128 && y<224)begin
 if(y==176 || x[5:0]==0)begin overlay_hit=1;overlay_c=24'h25394f;end
 if(wave_visible && y>=wave_y && y<wave_y+11'sd2)begin overlay_hit=1;overlay_c=24'h35d9f0;end
 end
 if(x>=1040 && x<1240 && y>=288 && y<384)begin
 if(y==383 || x[5:0]==0)begin overlay_hit=1;overlay_c=24'h25394f;end
 if(fft_visible && y>=10'd384-{3'd0,magnitude[7:1]})begin overlay_hit=1;overlay_c=24'hffbf55;end
 end
 if(x>=1072 && x<1200 && y>=456 && y<584)begin
 if(x==1136 || y==520)begin overlay_hit=1;overlay_c=24'h25394f;end
 if(xy_visible && xy_dot)begin overlay_hit=1;overlay_c=24'hc98aff;end
 end
 if((!state[31] || state[32]) && x>=384 && x<832 && y>=272 && y<352)begin overlay_hit=1;overlay_c=24'h233c58;end
 end
 integer n;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
 base_q<=0;overlay_q<=0;overlay_hit_q<=0;lane_hit_q<=0;gate_hit_q<=0;
 for(n=0;n<8;n=n+1)lane_q[n]<=0;
 end else begin
 gate_hit_q<=gate_hit;base_q<=base_c;overlay_q<=overlay_c;overlay_hit_q<=overlay_hit;lane_hit_q<=lane_hit;
 for(n=0;n<8;n=n+1)lane_q[n]<=lane_c[n];
 end
 wire[23:0] lanes_rgb=lane_q[0]|lane_q[1]|lane_q[2]|lane_q[3]|lane_q[4]|lane_q[5]|lane_q[6]|lane_q[7];
 always @*begin
 rgb=(|lane_hit_q)?lanes_rgb:(gate_hit_q?24'h8854e8:base_q);
 if(overlay_hit_q)rgb=overlay_q;
 end
endmodule

