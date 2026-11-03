`timescale 1ns/1ps
// One 64x64x4 ROM. All interaction is visual only, updated once per frame.
module video_ship(input clk,rst_n,input[10:0] x,input[9:0] y,
 input active,running,input[7:0] pressed,output reg hit,output reg[23:0] rgb);
 reg[3:0] pixels[0:4095];initial $readmemh("assets/ship64.hex",pixels);
 reg[10:0] center,goal;reg[2:0] lane;reg[7:0] previous;reg[3:0] glow;
 wire single=(pressed!=0) && ((pressed & (pressed-8'd1))==0);
 wire tick=x==0 && y==1;
 reg[2:0] chosen;
 always @*case(pressed)
  1:chosen=0;2:chosen=1;4:chosen=2;8:chosen=3;
  16:chosen=4;32:chosen=5;64:chosen=6;default:chosen=7;
 endcase
 // Track centers at y=496; plane moved up to leave room for a 94px tail.
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin center<=572;goal<=572;lane<=3;previous<=0;glow<=0;end
 else if(tick)begin
  previous<=pressed;
  if(!active)begin center<=572;goal<=572;lane<=3;glow<=0;end
  else begin
   if(single && pressed!=previous)begin lane<=chosen;goal<=11'd359+{8'd0,chosen}*11'd71;end
   if(running)begin
    if(center+11'd12<goal)center<=center+11'd12;
    else if(center>goal+11'd12)center<=center-11'd12;
    else center<=goal;
   end
   if(pressed!=0 || entering)glow<=15;else if(glow!=0)glow<=glow-1'b1;
  end
 end
 function[23:0] accent;input[2:0] n;begin case(n)
 0:accent=24'hff5c88;1:accent=24'hffb454;2:accent=24'hf2df68;3:accent=24'h5be0a0;
 4:accent=24'h47d9ff;5:accent=24'h648bff;6:accent=24'hb18aff;default:accent=24'hf280da;
 endcase end endfunction
 wire[10:0] sx=x-center+11'd32;
 reg[9:0] entry_y;
 wire[9:0] entry_gap=entry_y-10'd456;
 wire[9:0] entry_step=(entry_gap>>5)+10'd2;
 wire entering=active && entry_y>456;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)entry_y<=720;
 else if(tick)begin
  if(!active)entry_y<=720;
  else if(running || entry_y<=456+entry_step)entry_y<=456;
  else entry_y<=entry_y-entry_step;
 end
 wire[9:0] sy=y-entry_y;
 wire sprite_hit=active && pressed!=255 && sx<64 && sy<64;
 // Small display-only velocity filter: a slanted ribbon follows turns.
 reg signed[4:0] velocity;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)velocity<=0;
 else if(tick)begin
  if(!active || !running)velocity<=0;
  else if(center<goal && velocity<12)velocity<=velocity+1'b1;
  else if(center>goal && velocity> -12)velocity<=velocity-1'b1;
  else if(center==goal && velocity>0)velocity<=velocity-1'b1;
  else if(center==goal && velocity<0)velocity<=velocity+1'b1;
 end
 wire[9:0] tail_start=entry_y+10'd58;
 wire[9:0] tail_y=y-tail_start;
 reg[6:0] tail_y_q;
 reg signed[12:0] bend;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin tail_y_q<=0;bend<=0;end
 else begin tail_y_q<=tail_y[6:0];bend<=velocity*$signed({1'b0,tail_y_q});end
 wire signed[12:0] ribbon_next=$signed({2'd0,center})-(bend>>>4);
 reg[10:0] ribbon_center;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)ribbon_center<=572;
 else if(x<16)ribbon_center<=ribbon_next[10:0];
 wire[10:0] distance=x>=ribbon_center?x-ribbon_center:ribbon_center-x;
 wire tail_hit=active && pressed!=255 && glow!=0 && distance<13 && y>=tail_start && y<608;
 // 16 spatial brightness levels plus soft ribbon shoulders. No extra frame RAM.
 wire[10:0] fade_distance={1'b0,tail_y}+({1'b0,tail_y}>>2);
 wire[3:0] longitudinal=fade_distance>=120?4'd0:4'd15-fade_distance[6:3];
 wire[3:0] strength=glow<longitudinal?glow:longitudinal;
 wire[3:0] level=distance>=11?strength>>2:distance>=8?strength>>1:strength;
 wire[23:0] ac=accent(lane);
 // Explicit 4-input logic LUTs keep the gradient out of scarce BSRAM.
 wire[23:0] lane_rgb[0:7];
 wire[23:0] tail_rgb=lane_rgb[lane];
`ifdef __ICARUS__
 localparam[15:0] color_0_0=16'hcccc;
 assign lane_rgb[0][0]=color_0_0[level];
`else
 LUT4 #(.INIT(16'hcccc)) color_0_0(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][0]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_1=16'hf0f0;
 assign lane_rgb[0][1]=color_0_1[level];
`else
 LUT4 #(.INIT(16'hf0f0)) color_0_1(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][1]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_2=16'hff00;
 assign lane_rgb[0][2]=color_0_2[level];
`else
 LUT4 #(.INIT(16'hff00)) color_0_2(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][2]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_3=16'haaaa;
 assign lane_rgb[0][3]=color_0_3[level];
`else
 LUT4 #(.INIT(16'haaaa)) color_0_3(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][3]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_4=16'hcccc;
 assign lane_rgb[0][4]=color_0_4[level];
`else
 LUT4 #(.INIT(16'hcccc)) color_0_4(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][4]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_5=16'hf0f0;
 assign lane_rgb[0][5]=color_0_5[level];
`else
 LUT4 #(.INIT(16'hf0f0)) color_0_5(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][5]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_6=16'hff00;
 assign lane_rgb[0][6]=color_0_6[level];
`else
 LUT4 #(.INIT(16'hff00)) color_0_6(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][6]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_7=16'h0000;
 assign lane_rgb[0][7]=color_0_7[level];
`else
 LUT4 #(.INIT(16'h0000)) color_0_7(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][7]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_8=16'h1e1e;
 assign lane_rgb[0][8]=color_0_8[level];
`else
 LUT4 #(.INIT(16'h1e1e)) color_0_8(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][8]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_9=16'hab54;
 assign lane_rgb[0][9]=color_0_9[level];
`else
 LUT4 #(.INIT(16'hab54)) color_0_9(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][9]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_10=16'h9932;
 assign lane_rgb[0][10]=color_0_10[level];
`else
 LUT4 #(.INIT(16'h9932)) color_0_10(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][10]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_11=16'h2da4;
 assign lane_rgb[0][11]=color_0_11[level];
`else
 LUT4 #(.INIT(16'h2da4)) color_0_11(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][11]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_12=16'hce38;
 assign lane_rgb[0][12]=color_0_12[level];
`else
 LUT4 #(.INIT(16'hce38)) color_0_12(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][12]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_13=16'h0fc0;
 assign lane_rgb[0][13]=color_0_13[level];
`else
 LUT4 #(.INIT(16'h0fc0)) color_0_13(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][13]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_14=16'hf000;
 assign lane_rgb[0][14]=color_0_14[level];
`else
 LUT4 #(.INIT(16'hf000)) color_0_14(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][14]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_15=16'h0000;
 assign lane_rgb[0][15]=color_0_15[level];
`else
 LUT4 #(.INIT(16'h0000)) color_0_15(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][15]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_16=16'hfffe;
 assign lane_rgb[0][16]=color_0_16[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_0_16(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][16]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_17=16'hfffe;
 assign lane_rgb[0][17]=color_0_17[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_0_17(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][17]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_18=16'hfffe;
 assign lane_rgb[0][18]=color_0_18[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_0_18(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][18]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_19=16'hfffe;
 assign lane_rgb[0][19]=color_0_19[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_0_19(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][19]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_20=16'h5554;
 assign lane_rgb[0][20]=color_0_20[level];
`else
 LUT4 #(.INIT(16'h5554)) color_0_20(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][20]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_21=16'h9998;
 assign lane_rgb[0][21]=color_0_21[level];
`else
 LUT4 #(.INIT(16'h9998)) color_0_21(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][21]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_22=16'he1e0;
 assign lane_rgb[0][22]=color_0_22[level];
`else
 LUT4 #(.INIT(16'he1e0)) color_0_22(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][22]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_0_23=16'hfe00;
 assign lane_rgb[0][23]=color_0_23[level];
`else
 LUT4 #(.INIT(16'hfe00)) color_0_23(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[0][23]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_0=16'h5a5a;
 assign lane_rgb[1][0]=color_1_0[level];
`else
 LUT4 #(.INIT(16'h5a5a)) color_1_0(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][0]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_1=16'h936c;
 assign lane_rgb[1][1]=color_1_1[level];
`else
 LUT4 #(.INIT(16'h936c)) color_1_1(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][1]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_2=16'hb6da;
 assign lane_rgb[1][2]=color_1_2[level];
`else
 LUT4 #(.INIT(16'hb6da)) color_1_2(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][2]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_3=16'hdb6c;
 assign lane_rgb[1][3]=color_1_3[level];
`else
 LUT4 #(.INIT(16'hdb6c)) color_1_3(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][3]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_4=16'h1c70;
 assign lane_rgb[1][4]=color_1_4[level];
`else
 LUT4 #(.INIT(16'h1c70)) color_1_4(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][4]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_5=16'h1f80;
 assign lane_rgb[1][5]=color_1_5[level];
`else
 LUT4 #(.INIT(16'h1f80)) color_1_5(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][5]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_6=16'he000;
 assign lane_rgb[1][6]=color_1_6[level];
`else
 LUT4 #(.INIT(16'he000)) color_1_6(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][6]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_7=16'h0000;
 assign lane_rgb[1][7]=color_1_7[level];
`else
 LUT4 #(.INIT(16'h0000)) color_1_7(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][7]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_8=16'h5a5a;
 assign lane_rgb[1][8]=color_1_8[level];
`else
 LUT4 #(.INIT(16'h5a5a)) color_1_8(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][8]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_9=16'h39c6;
 assign lane_rgb[1][9]=color_1_9[level];
`else
 LUT4 #(.INIT(16'h39c6)) color_1_9(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][9]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_10=16'h5294;
 assign lane_rgb[1][10]=color_1_10[level];
`else
 LUT4 #(.INIT(16'h5294)) color_1_10(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][10]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_11=16'hc9b2;
 assign lane_rgb[1][11]=color_1_11[level];
`else
 LUT4 #(.INIT(16'hc9b2)) color_1_11(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][11]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_12=16'h6d24;
 assign lane_rgb[1][12]=color_1_12[level];
`else
 LUT4 #(.INIT(16'h6d24)) color_1_12(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][12]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_13=16'h8e38;
 assign lane_rgb[1][13]=color_1_13[level];
`else
 LUT4 #(.INIT(16'h8e38)) color_1_13(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][13]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_14=16'h0fc0;
 assign lane_rgb[1][14]=color_1_14[level];
`else
 LUT4 #(.INIT(16'h0fc0)) color_1_14(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][14]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_15=16'hf000;
 assign lane_rgb[1][15]=color_1_15[level];
`else
 LUT4 #(.INIT(16'hf000)) color_1_15(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][15]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_16=16'hfffe;
 assign lane_rgb[1][16]=color_1_16[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_1_16(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][16]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_17=16'hfffe;
 assign lane_rgb[1][17]=color_1_17[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_1_17(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][17]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_18=16'hfffe;
 assign lane_rgb[1][18]=color_1_18[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_1_18(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][18]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_19=16'hfffe;
 assign lane_rgb[1][19]=color_1_19[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_1_19(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][19]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_20=16'h5554;
 assign lane_rgb[1][20]=color_1_20[level];
`else
 LUT4 #(.INIT(16'h5554)) color_1_20(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][20]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_21=16'h9998;
 assign lane_rgb[1][21]=color_1_21[level];
`else
 LUT4 #(.INIT(16'h9998)) color_1_21(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][21]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_22=16'he1e0;
 assign lane_rgb[1][22]=color_1_22[level];
`else
 LUT4 #(.INIT(16'he1e0)) color_1_22(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][22]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_1_23=16'hfe00;
 assign lane_rgb[1][23]=color_1_23[level];
`else
 LUT4 #(.INIT(16'hfe00)) color_1_23(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[1][23]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_0=16'hcccc;
 assign lane_rgb[2][0]=color_2_0[level];
`else
 LUT4 #(.INIT(16'hcccc)) color_2_0(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][0]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_1=16'h5a5a;
 assign lane_rgb[2][1]=color_2_1[level];
`else
 LUT4 #(.INIT(16'h5a5a)) color_2_1(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][1]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_2=16'h39c6;
 assign lane_rgb[2][2]=color_2_2[level];
`else
 LUT4 #(.INIT(16'h39c6)) color_2_2(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][2]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_3=16'h5294;
 assign lane_rgb[2][3]=color_2_3[level];
`else
 LUT4 #(.INIT(16'h5294)) color_2_3(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][3]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_4=16'h6318;
 assign lane_rgb[2][4]=color_2_4[level];
`else
 LUT4 #(.INIT(16'h6318)) color_2_4(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][4]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_5=16'h83e0;
 assign lane_rgb[2][5]=color_2_5[level];
`else
 LUT4 #(.INIT(16'h83e0)) color_2_5(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][5]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_6=16'hfc00;
 assign lane_rgb[2][6]=color_2_6[level];
`else
 LUT4 #(.INIT(16'hfc00)) color_2_6(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][6]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_7=16'h0000;
 assign lane_rgb[2][7]=color_2_7[level];
`else
 LUT4 #(.INIT(16'h0000)) color_2_7(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][7]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_8=16'hfffe;
 assign lane_rgb[2][8]=color_2_8[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_2_8(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][8]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_9=16'h5554;
 assign lane_rgb[2][9]=color_2_9[level];
`else
 LUT4 #(.INIT(16'h5554)) color_2_9(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][9]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_10=16'h3332;
 assign lane_rgb[2][10]=color_2_10[level];
`else
 LUT4 #(.INIT(16'h3332)) color_2_10(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][10]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_11=16'h0f0e;
 assign lane_rgb[2][11]=color_2_11[level];
`else
 LUT4 #(.INIT(16'h0f0e)) color_2_11(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][11]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_12=16'haa54;
 assign lane_rgb[2][12]=color_2_12[level];
`else
 LUT4 #(.INIT(16'haa54)) color_2_12(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][12]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_13=16'h3398;
 assign lane_rgb[2][13]=color_2_13[level];
`else
 LUT4 #(.INIT(16'h3398)) color_2_13(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][13]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_14=16'hc3e0;
 assign lane_rgb[2][14]=color_2_14[level];
`else
 LUT4 #(.INIT(16'hc3e0)) color_2_14(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][14]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_15=16'hfc00;
 assign lane_rgb[2][15]=color_2_15[level];
`else
 LUT4 #(.INIT(16'hfc00)) color_2_15(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][15]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_16=16'h55aa;
 assign lane_rgb[2][16]=color_2_16[level];
`else
 LUT4 #(.INIT(16'h55aa)) color_2_16(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][16]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_17=16'hcc66;
 assign lane_rgb[2][17]=color_2_17[level];
`else
 LUT4 #(.INIT(16'hcc66)) color_2_17(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][17]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_18=16'h3c1e;
 assign lane_rgb[2][18]=color_2_18[level];
`else
 LUT4 #(.INIT(16'h3c1e)) color_2_18(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][18]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_19=16'h03fe;
 assign lane_rgb[2][19]=color_2_19[level];
`else
 LUT4 #(.INIT(16'h03fe)) color_2_19(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][19]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_20=16'h5554;
 assign lane_rgb[2][20]=color_2_20[level];
`else
 LUT4 #(.INIT(16'h5554)) color_2_20(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][20]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_21=16'h9998;
 assign lane_rgb[2][21]=color_2_21[level];
`else
 LUT4 #(.INIT(16'h9998)) color_2_21(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][21]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_22=16'he1e0;
 assign lane_rgb[2][22]=color_2_22[level];
`else
 LUT4 #(.INIT(16'he1e0)) color_2_22(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][22]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_2_23=16'hfe00;
 assign lane_rgb[2][23]=color_2_23[level];
`else
 LUT4 #(.INIT(16'hfe00)) color_2_23(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[2][23]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_0=16'h0000;
 assign lane_rgb[3][0]=color_3_0[level];
`else
 LUT4 #(.INIT(16'h0000)) color_3_0(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][0]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_1=16'haaaa;
 assign lane_rgb[3][1]=color_3_1[level];
`else
 LUT4 #(.INIT(16'haaaa)) color_3_1(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][1]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_2=16'hcccc;
 assign lane_rgb[3][2]=color_3_2[level];
`else
 LUT4 #(.INIT(16'hcccc)) color_3_2(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][2]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_3=16'h5a5a;
 assign lane_rgb[3][3]=color_3_3[level];
`else
 LUT4 #(.INIT(16'h5a5a)) color_3_3(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][3]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_4=16'h936c;
 assign lane_rgb[3][4]=color_3_4[level];
`else
 LUT4 #(.INIT(16'h936c)) color_3_4(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][4]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_5=16'h1c70;
 assign lane_rgb[3][5]=color_3_5[level];
`else
 LUT4 #(.INIT(16'h1c70)) color_3_5(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][5]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_6=16'h1f80;
 assign lane_rgb[3][6]=color_3_6[level];
`else
 LUT4 #(.INIT(16'h1f80)) color_3_6(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][6]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_7=16'he000;
 assign lane_rgb[3][7]=color_3_7[level];
`else
 LUT4 #(.INIT(16'he000)) color_3_7(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][7]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_8=16'h0000;
 assign lane_rgb[3][8]=color_3_8[level];
`else
 LUT4 #(.INIT(16'h0000)) color_3_8(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][8]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_9=16'haaaa;
 assign lane_rgb[3][9]=color_3_9[level];
`else
 LUT4 #(.INIT(16'haaaa)) color_3_9(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][9]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_10=16'h6666;
 assign lane_rgb[3][10]=color_3_10[level];
`else
 LUT4 #(.INIT(16'h6666)) color_3_10(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][10]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_11=16'h1e1e;
 assign lane_rgb[3][11]=color_3_11[level];
`else
 LUT4 #(.INIT(16'h1e1e)) color_3_11(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][11]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_12=16'hab54;
 assign lane_rgb[3][12]=color_3_12[level];
`else
 LUT4 #(.INIT(16'hab54)) color_3_12(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][12]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_13=16'h3398;
 assign lane_rgb[3][13]=color_3_13[level];
`else
 LUT4 #(.INIT(16'h3398)) color_3_13(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][13]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_14=16'hc3e0;
 assign lane_rgb[3][14]=color_3_14[level];
`else
 LUT4 #(.INIT(16'hc3e0)) color_3_14(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][14]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_15=16'hfc00;
 assign lane_rgb[3][15]=color_3_15[level];
`else
 LUT4 #(.INIT(16'hfc00)) color_3_15(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][15]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_16=16'he38e;
 assign lane_rgb[3][16]=color_3_16[level];
`else
 LUT4 #(.INIT(16'he38e)) color_3_16(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][16]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_17=16'h4ad4;
 assign lane_rgb[3][17]=color_3_17[level];
`else
 LUT4 #(.INIT(16'h4ad4)) color_3_17(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][17]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_18=16'hd9b2;
 assign lane_rgb[3][18]=color_3_18[level];
`else
 LUT4 #(.INIT(16'hd9b2)) color_3_18(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][18]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_19=16'h6d24;
 assign lane_rgb[3][19]=color_3_19[level];
`else
 LUT4 #(.INIT(16'h6d24)) color_3_19(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][19]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_20=16'h8e38;
 assign lane_rgb[3][20]=color_3_20[level];
`else
 LUT4 #(.INIT(16'h8e38)) color_3_20(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][20]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_21=16'h0fc0;
 assign lane_rgb[3][21]=color_3_21[level];
`else
 LUT4 #(.INIT(16'h0fc0)) color_3_21(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][21]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_22=16'hf000;
 assign lane_rgb[3][22]=color_3_22[level];
`else
 LUT4 #(.INIT(16'hf000)) color_3_22(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][22]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_3_23=16'h0000;
 assign lane_rgb[3][23]=color_3_23[level];
`else
 LUT4 #(.INIT(16'h0000)) color_3_23(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[3][23]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_0=16'hfffe;
 assign lane_rgb[4][0]=color_4_0[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_4_0(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][0]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_1=16'hfffe;
 assign lane_rgb[4][1]=color_4_1[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_4_1(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][1]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_2=16'hfffe;
 assign lane_rgb[4][2]=color_4_2[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_4_2(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][2]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_3=16'hfffe;
 assign lane_rgb[4][3]=color_4_3[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_4_3(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][3]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_4=16'h5554;
 assign lane_rgb[4][4]=color_4_4[level];
`else
 LUT4 #(.INIT(16'h5554)) color_4_4(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][4]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_5=16'h9998;
 assign lane_rgb[4][5]=color_4_5[level];
`else
 LUT4 #(.INIT(16'h9998)) color_4_5(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][5]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_6=16'he1e0;
 assign lane_rgb[4][6]=color_4_6[level];
`else
 LUT4 #(.INIT(16'he1e0)) color_4_6(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][6]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_7=16'hfe00;
 assign lane_rgb[4][7]=color_4_7[level];
`else
 LUT4 #(.INIT(16'hfe00)) color_4_7(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][7]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_8=16'hcc66;
 assign lane_rgb[4][8]=color_4_8[level];
`else
 LUT4 #(.INIT(16'hcc66)) color_4_8(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][8]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_9=16'h96b4;
 assign lane_rgb[4][9]=color_4_9[level];
`else
 LUT4 #(.INIT(16'h96b4)) color_4_9(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][9]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_10=16'h4d92;
 assign lane_rgb[4][10]=color_4_10[level];
`else
 LUT4 #(.INIT(16'h4d92)) color_4_10(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][10]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_11=16'hc38e;
 assign lane_rgb[4][11]=color_4_11[level];
`else
 LUT4 #(.INIT(16'hc38e)) color_4_11(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][11]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_12=16'h6ad4;
 assign lane_rgb[4][12]=color_4_12[level];
`else
 LUT4 #(.INIT(16'h6ad4)) color_4_12(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][12]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_13=16'h7318;
 assign lane_rgb[4][13]=color_4_13[level];
`else
 LUT4 #(.INIT(16'h7318)) color_4_13(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][13]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_14=16'h83e0;
 assign lane_rgb[4][14]=color_4_14[level];
`else
 LUT4 #(.INIT(16'h83e0)) color_4_14(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][14]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_15=16'hfc00;
 assign lane_rgb[4][15]=color_4_15[level];
`else
 LUT4 #(.INIT(16'hfc00)) color_4_15(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][15]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_16=16'h3398;
 assign lane_rgb[4][16]=color_4_16[level];
`else
 LUT4 #(.INIT(16'h3398)) color_4_16(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][16]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_17=16'hc3e0;
 assign lane_rgb[4][17]=color_4_17[level];
`else
 LUT4 #(.INIT(16'hc3e0)) color_4_17(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][17]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_18=16'h56aa;
 assign lane_rgb[4][18]=color_4_18[level];
`else
 LUT4 #(.INIT(16'h56aa)) color_4_18(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][18]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_19=16'h64cc;
 assign lane_rgb[4][19]=color_4_19[level];
`else
 LUT4 #(.INIT(16'h64cc)) color_4_19(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][19]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_20=16'h78f0;
 assign lane_rgb[4][20]=color_4_20[level];
`else
 LUT4 #(.INIT(16'h78f0)) color_4_20(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][20]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_21=16'h7f00;
 assign lane_rgb[4][21]=color_4_21[level];
`else
 LUT4 #(.INIT(16'h7f00)) color_4_21(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][21]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_22=16'h8000;
 assign lane_rgb[4][22]=color_4_22[level];
`else
 LUT4 #(.INIT(16'h8000)) color_4_22(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][22]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_4_23=16'h0000;
 assign lane_rgb[4][23]=color_4_23[level];
`else
 LUT4 #(.INIT(16'h0000)) color_4_23(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[4][23]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_0=16'hfffe;
 assign lane_rgb[5][0]=color_5_0[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_5_0(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][0]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_1=16'hfffe;
 assign lane_rgb[5][1]=color_5_1[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_5_1(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][1]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_2=16'hfffe;
 assign lane_rgb[5][2]=color_5_2[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_5_2(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][2]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_3=16'hfffe;
 assign lane_rgb[5][3]=color_5_3[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_5_3(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][3]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_4=16'h5554;
 assign lane_rgb[5][4]=color_5_4[level];
`else
 LUT4 #(.INIT(16'h5554)) color_5_4(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][4]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_5=16'h9998;
 assign lane_rgb[5][5]=color_5_5[level];
`else
 LUT4 #(.INIT(16'h9998)) color_5_5(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][5]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_6=16'he1e0;
 assign lane_rgb[5][6]=color_5_6[level];
`else
 LUT4 #(.INIT(16'he1e0)) color_5_6(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][6]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_7=16'hfe00;
 assign lane_rgb[5][7]=color_5_7[level];
`else
 LUT4 #(.INIT(16'hfe00)) color_5_7(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][7]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_8=16'h4924;
 assign lane_rgb[5][8]=color_5_8[level];
`else
 LUT4 #(.INIT(16'h4924)) color_5_8(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][8]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_9=16'h8e38;
 assign lane_rgb[5][9]=color_5_9[level];
`else
 LUT4 #(.INIT(16'h8e38)) color_5_9(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][9]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_10=16'h0fc0;
 assign lane_rgb[5][10]=color_5_10[level];
`else
 LUT4 #(.INIT(16'h0fc0)) color_5_10(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][10]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_11=16'h5aaa;
 assign lane_rgb[5][11]=color_5_11[level];
`else
 LUT4 #(.INIT(16'h5aaa)) color_5_11(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][11]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_12=16'h6ccc;
 assign lane_rgb[5][12]=color_5_12[level];
`else
 LUT4 #(.INIT(16'h6ccc)) color_5_12(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][12]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_13=16'h70f0;
 assign lane_rgb[5][13]=color_5_13[level];
`else
 LUT4 #(.INIT(16'h70f0)) color_5_13(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][13]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_14=16'h7f00;
 assign lane_rgb[5][14]=color_5_14[level];
`else
 LUT4 #(.INIT(16'h7f00)) color_5_14(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][14]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_15=16'h8000;
 assign lane_rgb[5][15]=color_5_15[level];
`else
 LUT4 #(.INIT(16'h8000)) color_5_15(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][15]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_16=16'hf0f0;
 assign lane_rgb[5][16]=color_5_16[level];
`else
 LUT4 #(.INIT(16'hf0f0)) color_5_16(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][16]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_17=16'h55aa;
 assign lane_rgb[5][17]=color_5_17[level];
`else
 LUT4 #(.INIT(16'h55aa)) color_5_17(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][17]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_18=16'hcc66;
 assign lane_rgb[5][18]=color_5_18[level];
`else
 LUT4 #(.INIT(16'hcc66)) color_5_18(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][18]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_19=16'h96b4;
 assign lane_rgb[5][19]=color_5_19[level];
`else
 LUT4 #(.INIT(16'h96b4)) color_5_19(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][19]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_20=16'he738;
 assign lane_rgb[5][20]=color_5_20[level];
`else
 LUT4 #(.INIT(16'he738)) color_5_20(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][20]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_21=16'h07c0;
 assign lane_rgb[5][21]=color_5_21[level];
`else
 LUT4 #(.INIT(16'h07c0)) color_5_21(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][21]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_22=16'hf800;
 assign lane_rgb[5][22]=color_5_22[level];
`else
 LUT4 #(.INIT(16'hf800)) color_5_22(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][22]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_5_23=16'h0000;
 assign lane_rgb[5][23]=color_5_23[level];
`else
 LUT4 #(.INIT(16'h0000)) color_5_23(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[5][23]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_0=16'hfffe;
 assign lane_rgb[6][0]=color_6_0[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_6_0(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][0]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_1=16'hfffe;
 assign lane_rgb[6][1]=color_6_1[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_6_1(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][1]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_2=16'hfffe;
 assign lane_rgb[6][2]=color_6_2[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_6_2(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][2]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_3=16'hfffe;
 assign lane_rgb[6][3]=color_6_3[level];
`else
 LUT4 #(.INIT(16'hfffe)) color_6_3(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][3]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_4=16'h5554;
 assign lane_rgb[6][4]=color_6_4[level];
`else
 LUT4 #(.INIT(16'h5554)) color_6_4(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][4]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_5=16'h9998;
 assign lane_rgb[6][5]=color_6_5[level];
`else
 LUT4 #(.INIT(16'h9998)) color_6_5(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][5]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_6=16'he1e0;
 assign lane_rgb[6][6]=color_6_6[level];
`else
 LUT4 #(.INIT(16'he1e0)) color_6_6(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][6]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_7=16'hfe00;
 assign lane_rgb[6][7]=color_6_7[level];
`else
 LUT4 #(.INIT(16'hfe00)) color_6_7(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][7]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_8=16'h936c;
 assign lane_rgb[6][8]=color_6_8[level];
`else
 LUT4 #(.INIT(16'h936c)) color_6_8(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][8]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_9=16'h1c70;
 assign lane_rgb[6][9]=color_6_9[level];
`else
 LUT4 #(.INIT(16'h1c70)) color_6_9(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][9]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_10=16'h1f80;
 assign lane_rgb[6][10]=color_6_10[level];
`else
 LUT4 #(.INIT(16'h1f80)) color_6_10(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][10]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_11=16'h4aaa;
 assign lane_rgb[6][11]=color_6_11[level];
`else
 LUT4 #(.INIT(16'h4aaa)) color_6_11(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][11]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_12=16'h6ccc;
 assign lane_rgb[6][12]=color_6_12[level];
`else
 LUT4 #(.INIT(16'h6ccc)) color_6_12(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][12]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_13=16'h70f0;
 assign lane_rgb[6][13]=color_6_13[level];
`else
 LUT4 #(.INIT(16'h70f0)) color_6_13(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][13]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_14=16'h7f00;
 assign lane_rgb[6][14]=color_6_14[level];
`else
 LUT4 #(.INIT(16'h7f00)) color_6_14(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][14]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_15=16'h8000;
 assign lane_rgb[6][15]=color_6_15[level];
`else
 LUT4 #(.INIT(16'h8000)) color_6_15(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][15]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_16=16'haaaa;
 assign lane_rgb[6][16]=color_6_16[level];
`else
 LUT4 #(.INIT(16'haaaa)) color_6_16(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][16]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_17=16'h6666;
 assign lane_rgb[6][17]=color_6_17[level];
`else
 LUT4 #(.INIT(16'h6666)) color_6_17(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][17]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_18=16'hb4b4;
 assign lane_rgb[6][18]=color_6_18[level];
`else
 LUT4 #(.INIT(16'hb4b4)) color_6_18(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][18]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_19=16'h6d92;
 assign lane_rgb[6][19]=color_6_19[level];
`else
 LUT4 #(.INIT(16'h6d92)) color_6_19(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][19]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_20=16'h4924;
 assign lane_rgb[6][20]=color_6_20[level];
`else
 LUT4 #(.INIT(16'h4924)) color_6_20(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][20]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_21=16'h8e38;
 assign lane_rgb[6][21]=color_6_21[level];
`else
 LUT4 #(.INIT(16'h8e38)) color_6_21(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][21]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_22=16'h0fc0;
 assign lane_rgb[6][22]=color_6_22[level];
`else
 LUT4 #(.INIT(16'h0fc0)) color_6_22(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][22]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_6_23=16'hf000;
 assign lane_rgb[6][23]=color_6_23[level];
`else
 LUT4 #(.INIT(16'hf000)) color_6_23(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[6][23]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_0=16'h39c6;
 assign lane_rgb[7][0]=color_7_0[level];
`else
 LUT4 #(.INIT(16'h39c6)) color_7_0(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][0]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_1=16'h5294;
 assign lane_rgb[7][1]=color_7_1[level];
`else
 LUT4 #(.INIT(16'h5294)) color_7_1(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][1]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_2=16'hc9b2;
 assign lane_rgb[7][2]=color_7_2[level];
`else
 LUT4 #(.INIT(16'hc9b2)) color_7_2(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][2]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_3=16'hc78e;
 assign lane_rgb[7][3]=color_7_3[level];
`else
 LUT4 #(.INIT(16'hc78e)) color_7_3(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][3]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_4=16'h6ad4;
 assign lane_rgb[7][4]=color_7_4[level];
`else
 LUT4 #(.INIT(16'h6ad4)) color_7_4(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][4]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_5=16'h7318;
 assign lane_rgb[7][5]=color_7_5[level];
`else
 LUT4 #(.INIT(16'h7318)) color_7_5(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][5]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_6=16'h83e0;
 assign lane_rgb[7][6]=color_7_6[level];
`else
 LUT4 #(.INIT(16'h83e0)) color_7_6(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][6]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_7=16'hfc00;
 assign lane_rgb[7][7]=color_7_7[level];
`else
 LUT4 #(.INIT(16'hfc00)) color_7_7(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][7]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_8=16'h0000;
 assign lane_rgb[7][8]=color_7_8[level];
`else
 LUT4 #(.INIT(16'h0000)) color_7_8(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][8]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_9=16'h0000;
 assign lane_rgb[7][9]=color_7_9[level];
`else
 LUT4 #(.INIT(16'h0000)) color_7_9(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][9]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_10=16'h0000;
 assign lane_rgb[7][10]=color_7_10[level];
`else
 LUT4 #(.INIT(16'h0000)) color_7_10(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][10]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_11=16'haaaa;
 assign lane_rgb[7][11]=color_7_11[level];
`else
 LUT4 #(.INIT(16'haaaa)) color_7_11(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][11]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_12=16'hcccc;
 assign lane_rgb[7][12]=color_7_12[level];
`else
 LUT4 #(.INIT(16'hcccc)) color_7_12(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][12]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_13=16'hf0f0;
 assign lane_rgb[7][13]=color_7_13[level];
`else
 LUT4 #(.INIT(16'hf0f0)) color_7_13(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][13]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_14=16'hff00;
 assign lane_rgb[7][14]=color_7_14[level];
`else
 LUT4 #(.INIT(16'hff00)) color_7_14(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][14]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_15=16'h0000;
 assign lane_rgb[7][15]=color_7_15[level];
`else
 LUT4 #(.INIT(16'h0000)) color_7_15(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][15]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_16=16'h55aa;
 assign lane_rgb[7][16]=color_7_16[level];
`else
 LUT4 #(.INIT(16'h55aa)) color_7_16(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][16]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_17=16'hcc66;
 assign lane_rgb[7][17]=color_7_17[level];
`else
 LUT4 #(.INIT(16'hcc66)) color_7_17(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][17]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_18=16'h3c1e;
 assign lane_rgb[7][18]=color_7_18[level];
`else
 LUT4 #(.INIT(16'h3c1e)) color_7_18(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][18]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_19=16'h03fe;
 assign lane_rgb[7][19]=color_7_19[level];
`else
 LUT4 #(.INIT(16'h03fe)) color_7_19(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][19]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_20=16'h5554;
 assign lane_rgb[7][20]=color_7_20[level];
`else
 LUT4 #(.INIT(16'h5554)) color_7_20(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][20]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_21=16'h9998;
 assign lane_rgb[7][21]=color_7_21[level];
`else
 LUT4 #(.INIT(16'h9998)) color_7_21(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][21]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_22=16'he1e0;
 assign lane_rgb[7][22]=color_7_22[level];
`else
 LUT4 #(.INIT(16'he1e0)) color_7_22(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][22]));
`endif
`ifdef __ICARUS__
 localparam[15:0] color_7_23=16'hfe00;
 assign lane_rgb[7][23]=color_7_23[level];
`else
 LUT4 #(.INIT(16'hfe00)) color_7_23(.I0(level[0]),.I1(level[1]),.I2(level[2]),.I3(level[3]),.F(lane_rgb[7][23]));
`endif
 // Eight-key feedback is an eight-colored flattened ring, no automatic score.
 wire[10:0] ring_dx=x>=608?x-11'd608:11'd608-x;
 wire[9:0] ring_dy=y>=570?y-10'd570:10'd570-y;
 wire[12:0] radius={2'b0,ring_dx}+{ring_dy,3'b000};
 wire ring_hit=active && pressed==255 && y>=526 && y<608 && radius>=260 && radius<272;
 wire[10:0] rx=x-11'd352;
 reg[3:0] code;reg sprite_q,tail_q,ring_q;reg[23:0] accent_q,tail_color_q,ring_color_q;
 always @(posedge clk)code<=pixels[{sy[5:0],sx[5:0]}];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin sprite_q<=0;tail_q<=0;ring_q<=0;accent_q<=0;tail_color_q<=0;ring_color_q<=0;end
 else begin sprite_q<=sprite_hit;tail_q<=tail_hit;ring_q<=ring_hit;accent_q<=ac;tail_color_q<=tail_rgb;ring_color_q<=accent(rx[8:6]);end
 always @*begin
  hit=tail_q || ring_q || (sprite_q && code!=0);rgb=tail_q?tail_color_q:ring_color_q;
  if(sprite_q && code!=0)case(code)
   1:rgb=24'h0c162c;2:rgb=24'h192e4c;3:rgb=24'h2f496f;4:rgb=24'h4d678f;
   5:rgb=24'h6f8ab2;6:rgb=24'h9eb4d2;7:rgb=24'hcad8ed;8:rgb=24'heff6ff;
   9:rgb=24'hffffff;10:rgb=24'h005ca0;11:rgb=24'h0097d2;12:rgb=24'h00cdf1;
   13:rgb=24'h64f0ff;14:rgb=24'he1ffff;default:rgb=accent_q;
  endcase
 end
endmodule
