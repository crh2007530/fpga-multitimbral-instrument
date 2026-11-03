`timescale 1ns/1ps
// 1280x720 raster, total1650x750, 74.166667MHz ->59.93266Hz.
// Full 1024 positive FFT bins are drawn one pixel per bin.
module video_dashboard #(parameter TEST128=0,CUSTOM_CHART=0,TIMED_CHART=0)(input wire[127:0] game_data,input wire pixel_clk,pixel_rst_n,sys_clk,sys_rst_n,
 input wire fft_valid,fft_done,input wire [9:0] fft_bin,
 input wire signed[23:0] fft_real,fft_imag,
 input wire audio_valid,input wire signed[15:0] audio_pcm,input wire[7:0] pressed,target,
 output wire hs,vs,de,output wire[7:0] red,green,blue,input[255:0] user_chart,input chart_enabled,input[63:0] test_mask64,input[(TEST128?7:6)-1:0] test_selected,input timed_enabled,timed_ready,input[39:0] timed_masks,input[79:0] timed_deltas,input[63:0] display_pressure,input[60:0] display_adsr,input title_write,input[8:0] title_address,input[7:0] title_data,input title_valid,input[21:0] display_pitch,input[63:0] display_mixer,input[23:0] display_pluck);
 reg[7:0] cr,cg,cb;wire dhi,dvi,dde;
 reg[10:0] x;reg[9:0] y;
 wire frame_start=x==0 && y==0;
 always @(posedge pixel_clk or negedge pixel_rst_n)
 if(!pixel_rst_n)begin x<=0;y<=0;end
 else if(x==1649)begin x<=0;if(y==749)y<=0;else y<=y+1'b1;end
 else x<=x+1'b1;
 wire[335:0] live;wire[335:0] source_ui;wire source_valid;
 generate if(TIMED_CHART && !CUSTOM_CHART)begin: unified_preview
  // The timed cache already publishes a coherent mask/delta bundle. Capture
  // it directly in the CDC mailbox instead of duplicating it in two stages.
  assign source_ui={timed_enabled,timed_deltas,test_mask64,test_selected[5:0],(TEST128?test_selected[6]:1'b0),timed_masks,game_data,target,pressed};
  assign source_valid=!timed_enabled || timed_ready;
 end else if(CUSTOM_CHART)begin: preview_builder
  // One time-shared chart read in the 50MHz domain, rather than five
  // variable-address muxes in the pixel domain. Publish masks and matching
  // game position together so a frame cannot show mismatched note positions.
  reg[80:0] captured_timed;reg[143:0] captured;reg[69:0] captured_test;reg enabled;reg[39:0] preview;reg[2:0] step;
  reg[335:0] bundle;reg valid;
  wire[6:0] address={1'b0,captured[37:32]}+step-1'b1;
  always @(posedge sys_clk or negedge sys_rst_n)
  if(!sys_rst_n)begin captured_timed<=0;captured<=0;captured_test<=0;enabled<=0;preview<=0;step<=0;bundle<=0;valid<=0;end
  else begin
   valid<=0;
   if(step==0 && (!TIMED_CHART || !timed_enabled || timed_ready))begin captured_timed<=TIMED_CHART?{timed_enabled,timed_deltas}:81'd0;if(TIMED_CHART && timed_enabled)preview<=timed_masks;captured<={game_data,target,pressed};captured_test<={test_mask64,test_selected[5:0]};enabled<=chart_enabled;step<=1;end
   else if(step!=0 && step<=5)begin if(!captured_timed[80])preview[(step-1'b1)*8+:8]<=address<32?user_chart[address[4:0]*8+:8]:8'd0;step<=step+1'b1;end
   else if(step!=0)begin bundle<={captured_timed,captured_test,enabled,preview,captured};valid<=1;step<=0;end
  end
  assign source_ui=bundle;assign source_valid=valid;
 end else begin
  assign source_ui={81'd0,test_mask64,test_selected[5:0],(TEST128?test_selected[6]:1'b0),40'd0,game_data,target,pressed};assign source_valid=1'b1;
 end endgenerate
 sample_mailbox #(.WIDTH(336)) ui_cross(sys_clk,sys_rst_n,source_valid,source_ui,pixel_clk,pixel_rst_n,,live);
 reg[335:0] snapshot;
 wire[115:0] detail_live;reg[115:0] detail;
 sample_mailbox #(.WIDTH(116)) details(sys_clk,sys_rst_n,1'b1,{display_pitch,title_valid,display_adsr[60],display_adsr[14:8],display_adsr[29:23],display_adsr[44:38],display_adsr[59:53],display_pressure},pixel_clk,pixel_rst_n,,detail_live);
 always @(posedge pixel_clk or negedge pixel_rst_n)if(!pixel_rst_n)detail<=0;else if(frame_start)detail<=detail_live;
 wire[23:0] pluck_live;reg[23:0] pluck_data;
 sample_mailbox #(.WIDTH(24)) pluck_ui(sys_clk,sys_rst_n,1'b1,display_pluck,pixel_clk,pixel_rst_n,,pluck_live);
 always @(posedge pixel_clk or negedge pixel_rst_n)if(!pixel_rst_n)pluck_data<=0;else if(frame_start)pluck_data<=pluck_live;
 wire[63:0] mixer_live;reg[63:0] mixer_data;
 sample_mailbox #(.WIDTH(64)) mix_ui(sys_clk,sys_rst_n,1'b1,display_mixer,pixel_clk,pixel_rst_n,,mixer_live);
 always @(posedge pixel_clk or negedge pixel_rst_n)if(!pixel_rst_n)mixer_data<=0;else if(frame_start)mixer_data<=mixer_live;
 wire[127:0] game=snapshot[143:16];
 wire game_active=game[30];wire test64=game[127] && game[126];
 always @(posedge pixel_clk or negedge pixel_rst_n)
 if(!pixel_rst_n)snapshot<=0;else if(frame_start)snapshot<=live;
 reg[7:0] magnitudes[0:2047];
 reg request,ack,accept_frame;reg[1:0] reqsync,acksync;
 reg visible;reg[7:0] magnitude_q;
 wire[23:0] ar=fft_real[23]?-fft_real:fft_real;
 wire[23:0] ai=fft_imag[23]?-fft_imag:fft_imag;
 reg[24:0] mag;reg fv1,fd1,fv2,fd2;reg[9:0] fb1,fb2;reg[7:0] height2;
 always @(posedge sys_clk or negedge sys_rst_n)
 if(!sys_rst_n)begin mag<=0;fv1<=0;fd1<=0;fv2<=0;fd2<=0;fb1<=0;fb2<=0;height2<=0;end
 else begin
 mag<={1'b0,ar}+{1'b0,ai};fv1<=fft_valid;fd1<=fft_done;fb1<=fft_bin;
 fv2<=fv1;fd2<=fd1;fb2<=fb1;height2<=(game_data[127] && game_data[126]) ? ((|mag[24:14])?8'd255:mag[13:6]) : height;end
 reg[7:0] height;integer k;
 always @*begin height=0;for(k=8;k<25;k=k+1)if(mag[k])height=(k-7)*10;end
 always @(posedge sys_clk or negedge sys_rst_n)
 if(!sys_rst_n)begin request<=0;acksync<=0;accept_frame<=0;end
 else begin
  acksync<={acksync[0],ack};
  if(fv2 && fb2==0)accept_frame<=request==acksync[1];
  if(fd2 && accept_frame)request<=~request;
 end
 always @(posedge sys_clk)
 if(sys_rst_n && fv2 && (fb2==0 ? request==acksync[1] : accept_frame))magnitudes[{~request,fb2}]<=height2;
 wire[10:0] spectrum_x=game_active ? x-11'd1040 : x-11'd128;
 wire[9:0] test_y=y-10'd128;
 wire[5:0] test_voice={test_y[8:7],spectrum_x[9:6]};
 // Inline the unchanged 64-tone mapping; retain every measured FFT address.
 wire[6:0] measured_voice={TEST128?snapshot[184]:1'b0,test_voice};
 reg[9:0] measured_tone_bin;
 always @*case(measured_voice)
 7'd0:measured_tone_bin=10'd11;
 7'd1:measured_tone_bin=10'd14;
 7'd2:measured_tone_bin=10'd18;
 7'd3:measured_tone_bin=10'd22;
 7'd4:measured_tone_bin=10'd25;
 7'd5:measured_tone_bin=10'd29;
 7'd6:measured_tone_bin=10'd32;
 7'd7:measured_tone_bin=10'd36;
 7'd8:measured_tone_bin=10'd39;
 7'd9:measured_tone_bin=10'd43;
 7'd10:measured_tone_bin=10'd46;
 7'd11:measured_tone_bin=10'd50;
 7'd12:measured_tone_bin=10'd53;
 7'd13:measured_tone_bin=10'd57;
 7'd14:measured_tone_bin=10'd60;
 7'd15:measured_tone_bin=10'd64;
 7'd16:measured_tone_bin=10'd68;
 7'd17:measured_tone_bin=10'd71;
 7'd18:measured_tone_bin=10'd75;
 7'd19:measured_tone_bin=10'd78;
 7'd20:measured_tone_bin=10'd82;
 7'd21:measured_tone_bin=10'd85;
 7'd22:measured_tone_bin=10'd89;
 7'd23:measured_tone_bin=10'd92;
 7'd24:measured_tone_bin=10'd96;
 7'd25:measured_tone_bin=10'd99;
 7'd26:measured_tone_bin=10'd103;
 7'd27:measured_tone_bin=10'd106;
 7'd28:measured_tone_bin=10'd110;
 7'd29:measured_tone_bin=10'd114;
 7'd30:measured_tone_bin=10'd117;
 7'd31:measured_tone_bin=10'd121;
 7'd32:measured_tone_bin=10'd124;
 7'd33:measured_tone_bin=10'd128;
 7'd34:measured_tone_bin=10'd131;
 7'd35:measured_tone_bin=10'd135;
 7'd36:measured_tone_bin=10'd138;
 7'd37:measured_tone_bin=10'd142;
 7'd38:measured_tone_bin=10'd145;
 7'd39:measured_tone_bin=10'd149;
 7'd40:measured_tone_bin=10'd152;
 7'd41:measured_tone_bin=10'd156;
 7'd42:measured_tone_bin=10'd160;
 7'd43:measured_tone_bin=10'd163;
 7'd44:measured_tone_bin=10'd167;
 7'd45:measured_tone_bin=10'd170;
 7'd46:measured_tone_bin=10'd174;
 7'd47:measured_tone_bin=10'd177;
 7'd48:measured_tone_bin=10'd181;
 7'd49:measured_tone_bin=10'd184;
 7'd50:measured_tone_bin=10'd188;
 7'd51:measured_tone_bin=10'd191;
 7'd52:measured_tone_bin=10'd195;
 7'd53:measured_tone_bin=10'd198;
 7'd54:measured_tone_bin=10'd202;
 7'd55:measured_tone_bin=10'd206;
 7'd56:measured_tone_bin=10'd209;
 7'd57:measured_tone_bin=10'd213;
 7'd58:measured_tone_bin=10'd216;
 7'd59:measured_tone_bin=10'd220;
 7'd60:measured_tone_bin=10'd223;
 7'd61:measured_tone_bin=10'd227;
 7'd62:measured_tone_bin=10'd230;
 7'd63:measured_tone_bin=10'd234;
 7'd64:measured_tone_bin=10'd237;
 7'd65:measured_tone_bin=10'd241;
 7'd66:measured_tone_bin=10'd244;
 7'd67:measured_tone_bin=10'd248;
 7'd68:measured_tone_bin=10'd252;
 7'd69:measured_tone_bin=10'd255;
 7'd70:measured_tone_bin=10'd259;
 7'd71:measured_tone_bin=10'd262;
 7'd72:measured_tone_bin=10'd266;
 7'd73:measured_tone_bin=10'd269;
 7'd74:measured_tone_bin=10'd273;
 7'd75:measured_tone_bin=10'd276;
 7'd76:measured_tone_bin=10'd280;
 7'd77:measured_tone_bin=10'd283;
 7'd78:measured_tone_bin=10'd287;
 7'd79:measured_tone_bin=10'd290;
 7'd80:measured_tone_bin=10'd294;
 7'd81:measured_tone_bin=10'd298;
 7'd82:measured_tone_bin=10'd301;
 7'd83:measured_tone_bin=10'd305;
 7'd84:measured_tone_bin=10'd308;
 7'd85:measured_tone_bin=10'd312;
 7'd86:measured_tone_bin=10'd315;
 7'd87:measured_tone_bin=10'd319;
 7'd88:measured_tone_bin=10'd322;
 7'd89:measured_tone_bin=10'd326;
 7'd90:measured_tone_bin=10'd329;
 7'd91:measured_tone_bin=10'd333;
 7'd92:measured_tone_bin=10'd336;
 7'd93:measured_tone_bin=10'd340;
 7'd94:measured_tone_bin=10'd344;
 7'd95:measured_tone_bin=10'd347;
 7'd96:measured_tone_bin=10'd351;
 7'd97:measured_tone_bin=10'd354;
 7'd98:measured_tone_bin=10'd358;
 7'd99:measured_tone_bin=10'd361;
 7'd100:measured_tone_bin=10'd365;
 7'd101:measured_tone_bin=10'd368;
 7'd102:measured_tone_bin=10'd372;
 7'd103:measured_tone_bin=10'd375;
 7'd104:measured_tone_bin=10'd379;
 7'd105:measured_tone_bin=10'd382;
 7'd106:measured_tone_bin=10'd386;
 7'd107:measured_tone_bin=10'd390;
 7'd108:measured_tone_bin=10'd393;
 7'd109:measured_tone_bin=10'd397;
 7'd110:measured_tone_bin=10'd400;
 7'd111:measured_tone_bin=10'd404;
 7'd112:measured_tone_bin=10'd407;
 7'd113:measured_tone_bin=10'd411;
 7'd114:measured_tone_bin=10'd414;
 7'd115:measured_tone_bin=10'd418;
 7'd116:measured_tone_bin=10'd421;
 7'd117:measured_tone_bin=10'd425;
 7'd118:measured_tone_bin=10'd428;
 7'd119:measured_tone_bin=10'd432;
 7'd120:measured_tone_bin=10'd436;
 7'd121:measured_tone_bin=10'd439;
 7'd122:measured_tone_bin=10'd443;
 7'd123:measured_tone_bin=10'd446;
 7'd124:measured_tone_bin=10'd450;
 7'd125:measured_tone_bin=10'd453;
 7'd126:measured_tone_bin=10'd457;
 7'd127:measured_tone_bin=10'd460;
 default:measured_tone_bin=0;endcase
 wire[9:0] fft_read_bin=test64?measured_tone_bin:spectrum_x[9:0];
 always @(posedge pixel_clk)magnitude_q<=magnitudes[{ack,fft_read_bin}];
 always @(posedge pixel_clk or negedge pixel_rst_n)
 if(!pixel_rst_n)begin reqsync<=0;ack<=0;visible<=0;end
 else begin
  reqsync<={reqsync[0],request};
  if(frame_start && reqsync[1]!=ack)begin ack<=reqsync[1];visible<=1;end
 end
 reg[10:0] dx,read_x;reg[9:0] dy,read_y;
 always @(posedge pixel_clk)begin read_x<=x;read_y<=y;dx<=read_x;dy<=read_y;end
 assign dde=dx<1280 && dy<720;
 assign dhi=dx>=1390 && dx<1430;
 assign dvi=dy>=725 && dy<730;
 wire[10:0] wx=dx-11'd128;
 wire signed[8:0] raw_displacement;wire raw_wave_visible;
 reg signed[8:0] wave_displacement;reg wave_visible;
 reg[7:0] magnitude_draw;reg xy_draw,xy_visible_draw;
 always @(posedge pixel_clk or negedge pixel_rst_n)
 if(!pixel_rst_n)begin wave_displacement<=0;wave_visible<=0;magnitude_draw<=0;xy_draw<=0;xy_visible_draw<=0;end
 else begin wave_displacement<=raw_displacement;wave_visible<=raw_wave_visible;magnitude_draw<=magnitude_q;xy_draw<=xy_dot;xy_visible_draw<=xy_visible;end
 video_wave_capture scope(sys_clk,sys_rst_n,audio_valid,audio_pcm,pixel_clk,pixel_rst_n,frame_start,spectrum_x[9:0],raw_displacement,raw_wave_visible);
 wire signed[10:0] wy=11'sd224-{{2{wave_displacement[8]}},wave_displacement};
 wire[2:0] pad=wx[9:7];
 wire xy_dot,xy_visible;
 wire[10:0] xy_x=game_active ? x-11'd1072 : x-11'd896;
 wire[9:0] xy_y=game_active ? y-10'd456 : y-10'd96;
 video_xy_capture xy_scope(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),
  .sample_valid(audio_valid),.pcm(audio_pcm),.pixel_clk(pixel_clk),.pixel_rst_n(pixel_rst_n),
  .frame_start(frame_start),.read_address(game_active?{xy_y[6:0],xy_x[6:0]}:{xy_y[7:1],xy_x[7:1]}),.dot(xy_dot),.visible(xy_visible));
 wire[23:0] game_rgb;
 video_game_view #(.CUSTOM_CHART(CUSTOM_CHART),.TIMED_CHART(TIMED_CHART)) game_view(pixel_clk,pixel_rst_n,dx,dy,game,snapshot[7:0],magnitude_draw,wave_displacement,wave_visible,visible,xy_visible_draw,xy_draw,game_rgb,snapshot[183:144],snapshot[184],snapshot[335],snapshot[334:255]);
 wire[23:0] test_rgb;
 generate if(TEST128)begin:wide_test
 video_test128 test_page(dx,dy,magnitude_draw,visible,snapshot[254:191],snapshot[190:185],test_rgb,snapshot[184]);
 end else begin:narrow_test
 video_test64 test_page(dx,dy,magnitude_draw,visible,snapshot[254:191],snapshot[190:185],test_rgb);
 end endgenerate
 // White instrument dashboard: all graphics come from live hardware data.
 wire[10:0] pressure_read_x=read_x-11'd128;
 reg[7:0] pressure_level;
 always @(posedge pixel_clk)pressure_level<=detail[pressure_read_x[9:7]*8+:8];
 reg[6:0] env_value;
 always @(posedge pixel_clk)env_value<=(read_x<384)?detail[91:85]:(read_x<640)?detail[84:78]:(read_x<896)?detail[77:71]:detail[70:64];
 always @*begin
  {cr,cg,cb}=24'hf5f9fd;
  if(dy<64){cr,cg,cb}=24'hffffff;
  if((dx>=112 && dx<784 && dy>=112 && dy<344) ||
     (dx>=880 && dx<1168 && dy>=112 && dy<360) ||
     (dx>=112 && dx<1168 && dy>=360 && dy<560)) {cr,cg,cb}=24'h0b1930;
  if((dx>=112 && dx<784 && (dy==112 || dy==343)) ||
     (dx>=880 && dx<1168 && (dy==112 || dy==359)) ||
     (dx>=112 && dx<1168 && (dy==360 || dy==559))) {cr,cg,cb}=24'hb9d7eb;
  if(dx>=128 && dx<1152)begin
   if(dx<768 && dy>=128 && dy<=320)begin
    if(dx[6:0]==0 || dy[5:0]==0){cr,cg,cb}=24'h253b52;
    if(wave_visible && $signed({1'b0,dy})>=wy-11'sd1 && $signed({1'b0,dy})<wy+11'sd3){cr,cg,cb}=24'h36e6f4;
   end
   if(dy>=400 && dy<=544)begin
    if(dx[6:0]==0 || dy[5:0]==0){cr,cg,cb}=24'h253b52;
    if(visible && magnitude_draw!=0 && dy>=10'd544-{3'd0,magnitude_draw[7:1]})begin
     {cr,cg,cb}=dy[6]?24'hffb520:24'hef8b16;
    end
   end
   if(dy>=576 && dy<616 && wx[6:0]<112)begin
    {cr,cg,cb}=snapshot[pad]?24'hd6f8ed:snapshot[8+pad]?24'hfff0ca:24'he5eff7;
    if(dy>=604 && dy<610 && wx[6:0]>=8 && wx[6:0]<104)begin
     {cr,cg,cb}=24'hc3dce9;
     if(wx[6:0]-7'd8<{1'b0,pressure_level[7:2]}){cr,cg,cb}=24'h00b993;
    end
   end
   if(dy>=674 && dy<680 && wx[7:0]<128)begin
     {cr,cg,cb}=24'hd6e6f2;
     if(detail[92] && wx[6:0]<env_value){cr,cg,cb}=24'h00aaca;
   end
  end
  if(dx>=896 && dx<1152 && dy>=112 && dy<352)begin
   if(dx[5:0]==0 || dy==224 || dy==351 || dx==1151){cr,cg,cb}=24'h253b52;
   if(xy_visible_draw && xy_draw){cr,cg,cb}=24'hc59aff;
  end
  if(dx>=112 && dx<784 && dy>=112 && dy<128){cr,cg,cb}=24'hffffff;
  if(dx>=112 && dx<1168 && dy>=360 && dy<392){cr,cg,cb}=24'hffffff;
  if(dy==63){cr,cg,cb}=24'h00a5cc;
  // True instrument selection; these are indicators, not screen buttons.
  if(dy>=72 && dy<96 && dx>=128 && dx<512)begin
   {cr,cg,cb}=24'he1edf6;
   if((dx<256 && !game[120] && !game[121]) || (dx>=256 && dx<384 && game[121] && !game[120]) || (dx>=384 && game[120])){cr,cg,cb}=24'h8be3f3;
  end
  if(test64){cr,cg,cb}=test_rgb;
  if(!dde){cr,cg,cb}=0;
 end
// Align the normal dashboard, coordinates and syncs with the game layer stage.
reg[23:0] normal_q;reg[10:0] label_x;reg[9:0] label_y;
reg hs_q,vs_q,de_q,game_q;
always @(posedge pixel_clk or negedge pixel_rst_n)
if(!pixel_rst_n)begin normal_q<=0;label_x<=0;label_y<=0;hs_q<=0;vs_q<=0;de_q<=0;game_q<=0;end
else begin normal_q<={cr,cg,cb};label_x<=dx;label_y<=dy;hs_q<=dhi;vs_q<=dvi;de_q<=dde;game_q<=game_active;end
wire[23:0] composed_rgb=de_q?(game_q?game_rgb:normal_q):24'd0;
wire[23:0] labeled;wire lh,lv,ld;
reg signed[8:0] mixer_wave;reg mixer_wv;
always @(posedge pixel_clk)begin mixer_wave<=wave_displacement;mixer_wv<=wave_visible;end
video_labels labels(game,pixel_clk,pixel_rst_n,label_x,label_y,hs_q,vs_q,de_q,composed_rgb,lh,lv,ld,labeled,detail[92],detail[115:94],mixer_data,mixer_wave,mixer_wv,pluck_data);
video_brand_title identity(.clk(pixel_clk),.rst_n(pixel_rst_n),.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.title_write(title_write),.title_address(title_address),.title_data(title_data),.title_show(detail[93] && game[104]),.game_active(game_active),.test_mode(game[127]),.x(label_x),.y(label_y),.hi(lh),.vi(lv),.di(ld),.rgb_in(labeled),.ho(hs),.vo(vs),.do_(de),.rgb_out({red,green,blue}));
endmodule

