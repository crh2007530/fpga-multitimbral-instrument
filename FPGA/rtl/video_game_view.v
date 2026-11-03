`timescale 1ns/1ps
module video_game_view #(parameter CUSTOM_CHART=0,TIMED_CHART=0)(input wire clk,rst_n,input wire[10:0] x,input wire[9:0] y,
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
 // One shared quarter-note time calculation for all five preview notes.
 wire[5:0] base_beats=chart_beat(position);
 wire signed[17:0] base_standard=$signed({12'd0,base_beats})*18'sd500;
 wire[1:0] speed=state[103:102];
 wire signed[17:0] base_due=18'sd2000+(speed==0?base_standard<<<1:speed==2?base_standard>>>1:base_standard);
 // Frame state changes in the header, far before the first note scanline.
 // Split chart-time arithmetic across clocks; this is display-only latency.
 reg signed[17:0] base_due_q,standard_q,scaled_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin base_due_q<=0;standard_q<=0;scaled_q<=0;end
 else begin standard_q<=base_standard;scaled_q<=speed==0?standard_q<<<1:speed==2?standard_q>>>1:standard_q;base_due_q<=18'sd2000+scaled_q;end
 function[2:0] phrase_phase;input[5:0] pos;begin case(pos)
0,7,14,21,28,35:phrase_phase=3'd0;
1,8,15,22,29,36:phrase_phase=3'd1;
2,9,16,23,30,37:phrase_phase=3'd2;
3,10,17,24,31,38:phrase_phase=3'd3;
4,11,18,25,32,39:phrase_phase=3'd4;
5,12,19,26,33,40:phrase_phase=3'd5;
6,13,20,27,34,41:phrase_phase=3'd6;
default:phrase_phase=0;endcase end endfunction
 wire[2:0] phase=phrase_phase(position);
 genvar q;
 generate for(q=0;q<5;q=q+1)begin:positions
 localparam [5:0] STEP=q,LAST=41-q;
 wire cross_phrase=(q!=0) && phase>=7-q;
 localparam signed[17:0] EXTRA=q*500;
 wire signed[17:0] extra_standard=EXTRA+(cross_phrase?18'sd500:18'sd0);
 reg signed[17:0] extra_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)extra_q<=0;
 else extra_q<=speed==0?extra_standard<<<1:speed==2?extra_standard>>>1:extra_standard;
 wire signed[17:0] fall_delta=timed?delta2[q]>>>2:speed==0?delta2[q]>>>3:speed==2?delta2[q]>>>1:delta2[q]>>>2;
 localparam signed[17:0] OFFSET=2000+q*500;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  due1[q]<=0;delta2[q]<=0;bottom3[q]<=0;top3[q]<=0;mask1[q]<=0;mask2[q]<=0;mask3[q]<=0;chord3[q]<=0;
 end else begin
   due1[q]<=(CUSTOM_CHART && chart_enabled)?OFFSET+$signed({12'd0,position})*18'sd500:base_due_q+extra_q;
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
 // One geometry update per scanline; no framebuffer, divider or multiplier IP.
 reg[10:0] edge_x[0:8];reg[7:0] row_notes,row_chords;
 reg[7:0] next_notes,next_chords;integer j,k;
 wire[9:0] depth=y>=160?y-10'd160:10'd0;
 // Sixteenth-pixel precision retained until each individual edge is rounded.
 wire[13:0] width_fp=14'd128+{4'd0,depth}+({4'd0,depth}<<1);
 wire[13:0] three_width_fp=width_fp+(width_fp<<1);
 wire[10:0] w1={1'b0,width_fp[13:4]},w2=width_fp[13:3],w3={1'b0,three_width_fp[13:4]},w4=width_fp[12:2];
 // Precompute bevel boundaries once per scanline. No new texture/frame RAM.
 reg[10:0] rail_l[0:4],rail_r[0:4];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin rail_l[0]<=0;rail_l[1]<=0;rail_l[2]<=0;rail_l[3]<=0;rail_l[4]<=0;
 rail_r[0]<=0;rail_r[1]<=0;rail_r[2]<=0;rail_r[3]<=0;rail_r[4]<=0;end
 else if(x==0)begin
 rail_l[0]<=11'd590-w4;rail_l[1]<=11'd592-w4;
 rail_l[2]<=11'd598-w4;rail_l[3]<=11'd600-w4;rail_l[4]<=11'd606-w4;
 rail_r[0]<=11'd610+w4;rail_r[1]<=11'd616+w4;
 rail_r[2]<=11'd618+w4;rail_r[3]<=11'd624+w4;rail_r[4]<=11'd626+w4;
 end
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
 edge_x[0]<=11'd608 - w4;
edge_x[1]<=11'd608 - w3;
edge_x[2]<=11'd608 - w2;
edge_x[3]<=11'd608 - w1;
edge_x[4]<=11'd608 + 11'd0;
edge_x[5]<=11'd608 + w1;
edge_x[6]<=11'd608 + w2;
edge_x[7]<=11'd608 + w3;
edge_x[8]<=11'd608 + w4;
 end
 // Precompute per-lane bevels at x=1; the first road pixel is much later.
 reg[10:0] left3[0:7],left4[0:7],left5[0:7],left7[0:7],right4[0:7],right5[0:7],right7[0:7];integer e;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin for(e=0;e<8;e=e+1)begin left3[e]<=0;left4[e]<=0;left5[e]<=0;left7[e]<=0;right4[e]<=0;right5[e]<=0;right7[e]<=0;end end
 else if(x==1)begin for(e=0;e<8;e=e+1)begin
 left3[e]<=edge_x[e]+11'd3;left4[e]<=edge_x[e]+11'd4;left5[e]<=edge_x[e]+11'd5;left7[e]<=edge_x[e]+11'd7;
 right4[e]<=edge_x[e+1]-11'd4;right5[e]<=edge_x[e+1]-11'd5;right7[e]<=edge_x[e+1]-11'd7;
 end end
 wire[9:0] motion_y=y+{4'd0,time_ms[8:3]};
 reg rail_hit;reg[2:0] rail_color,rail_color_q;reg rail_hit_q;
 always @*begin
 rail_hit=0;rail_color=0;
 if(y>=160 && y<608)begin
 if(x>=rail_l[0] && x<rail_l[4])begin
 rail_hit=1;
 if(x<rail_l[1])rail_color=1;
 else if(x<rail_l[2])rail_color=motion_y[4]?3'd2:3'd3;
 else if(x<rail_l[3])rail_color=4;else rail_color=5;
 end
 if(x>=rail_r[0] && x<rail_r[4])begin
 rail_hit=1;
 if(x<rail_r[1])rail_color=5;
 else if(x<rail_r[2])rail_color=4;
 else if(x<rail_r[3])rail_color=motion_y[4]?3'd2:3'd3;else rail_color=1;
 end
 end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin rail_hit_q<=0;rail_color_q<=0;end
 else begin rail_hit_q<=rail_hit;rail_color_q<=rail_color;end
 reg[23:0] rail_rgb;
 always @*case(rail_color_q)
 1:rail_rgb=24'h3378a5;2:rail_rgb=24'hf6cc63;3:rail_rgb=24'h24415c;
 4:rail_rgb=24'hd6ffff;default:rail_rgb=24'h16badd;
 endcase
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
 wire[10:0] tri_outer=y>=96?{1'b0,y}-11'd96:11'd0;
 wire[10:0] tri_inner=y>=128?{1'b0,y}-11'd128:11'd0;
 wire gate_gold=y>=96 && y<288 && ((gate_dx>=tri_outer && gate_dx<tri_outer+11'd4) || (y>=284 && gate_dx<192));
 wire gate_cyan=y>=128 && y<256 && ((gate_dx>=tri_inner && gate_dx<tri_inner+11'd3) || (y>=253 && gate_dx<128));
 wire gate_hit=gate_gold || gate_cyan;
 reg gate_cyan_q;
 reg[4:0] lane_c[0:7],lane_q[0:7];reg[7:0] lane_hit,lane_hit_q;
 integer lane;reg signed[10:0] wave_y;
 wire[11:0] gate_distance={1'b0,gate_dx}+{2'd0,gate_dy};
 wire[11:0] progress_end=state[32]?12'd1000:12'd32+{6'd0,position}*12'd23;
 always @*begin
 base_c={8'h05,8'h0c,(8'h20+{3'd0,y[9:5]})};overlay_c=0;overlay_hit=0;
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
 
 if(y>=160 && y<608 && x>=edge_x[lane] && x<edge_x[lane+1])begin
 lane_hit[lane]=1;lane_c[lane]=lane[0]?5'd25:5'd26;
 if(motion_y[5:0]<2)lane_c[lane]=5'd27;
 if(x<left3[lane])lane_c[lane]=5'd1+lane;
 if(pressed[lane] && y>=488)lane_c[lane]=5'd9+lane;
 if(hit_age[lane]!=0 && y>=10'd608-{3'd0,hit_age[lane],3'b000})
 lane_c[lane]=5'd17+lane;
 if(row_notes[lane] && x>=left4[lane] && x<right4[lane])
 begin
 lane_c[lane]=row_chords[lane]?5'd29:5'd1+lane;
 // Bevels and inner light make note blocks readable without texture RAM.
 if(x<left7[lane] || x>=right7[lane])lane_c[lane]=5'd30;
 end
 if(pressed[lane] && y>=592 && (x<left5[lane] || x>=right5[lane]))lane_c[lane]=5'd1+lane;
 end
 if(y>=624 && y<680 && x>=224+lane*96 && x<320+lane*96)begin
 lane_hit[lane]=1;lane_c[lane]=pressed[lane]?(5'd1+lane):5'd31;
 if(y>=672 || y<628)lane_c[lane]=5'd1+lane;
 if(hit_age[lane]!=0 && (y<632 || y>=668))lane_c[lane]=5'd30;
 if(x==224+lane*96 || x==319+lane*96)lane_c[lane]=5'd0;
 end
 end
 if(judge_age!=0 && x>=400 && x<816 && y>=76 && y<100)begin
 overlay_hit=1;overlay_c=(state[35:33]==1)?24'h156756:(state[35:33]==2)?24'h245c83:24'h702f4c;
 end
 if(x>=224 && x<992 && y>=612 && y<620)begin overlay_hit=1;overlay_c=24'h164b61;end
 if(x>=224 && x<992 && y>=608 && y<612)begin overlay_hit=1;overlay_c=24'hd5fff7;end
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
 wire ship_hit;wire[23:0] ship_rgb;
 video_ship plane(clk,rst_n,x,y,state[30],state[31],pressed,ship_hit,ship_rgb);
 integer n;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
 base_q<=0;overlay_q<=0;overlay_hit_q<=0;lane_hit_q<=0;gate_hit_q<=0;gate_cyan_q<=0;
 for(n=0;n<8;n=n+1)lane_q[n]<=0;
 end else begin
 gate_hit_q<=gate_hit;gate_cyan_q<=gate_cyan;base_q<=base_c;overlay_q<=overlay_c;overlay_hit_q<=overlay_hit;lane_hit_q<=lane_hit;
 for(n=0;n<8;n=n+1)lane_q[n]<=lane_c[n];
 end
function[23:0] palette;input[4:0] code;begin case(code)
5'd0:palette=24'h080f21;
5'd1:palette=24'hff5c88;
5'd2:palette=24'hffb454;
5'd3:palette=24'hf2df68;
5'd4:palette=24'h5be0a0;
5'd5:palette=24'h47d9ff;
5'd6:palette=24'h648bff;
5'd7:palette=24'hb18aff;
5'd8:palette=24'hf280da;
5'd9:palette=24'h3f1722;
5'd10:palette=24'h3f2d15;
5'd11:palette=24'h3c371a;
5'd12:palette=24'h163828;
5'd13:palette=24'h11363f;
5'd14:palette=24'h19223f;
5'd15:palette=24'h2c223f;
5'd16:palette=24'h3c2036;
5'd17:palette=24'h7f2e44;
5'd18:palette=24'h7f5a2a;
5'd19:palette=24'h796f34;
5'd20:palette=24'h2d7050;
5'd21:palette=24'h236c7f;
5'd22:palette=24'h32457f;
5'd23:palette=24'h58457f;
5'd24:palette=24'h79406d;
5'd25:palette=24'h10213a;
5'd26:palette=24'h0c1628;
5'd27:palette=24'h214266;
5'd28:palette=24'h3975a0;
5'd29:palette=24'hffcb68;
5'd30:palette=24'he5f4ff;
5'd31:palette=24'h142139;
default:palette=0;endcase end endfunction
 wire[4:0] lane_code=lane_q[0]|lane_q[1]|lane_q[2]|lane_q[3]|lane_q[4]|lane_q[5]|lane_q[6]|lane_q[7];
 wire[23:0] lanes_rgb=palette(lane_code);
 always @*begin
 rgb=(|lane_hit_q)?lanes_rgb:(gate_hit_q?(gate_cyan_q?24'h24d9f5:24'hf5c34c):base_q);
 if(rail_hit_q)rgb=rail_rgb;
 if(overlay_hit_q)rgb=overlay_q;
 if(ship_hit)rgb=ship_rgb;
 end
endmodule
