`timescale 1ns/1ps
module video_labels_reference(input wire[127:0] game,input wire clk,rst_n,input wire[10:0] x,input wire[9:0] y,
 input wire hi,vi,di,input wire[23:0] rgb_in,
 output reg ho,vo,do_,output reg[23:0] rgb_out,input user_envelope,input[21:0] pitch_status,input[63:0] mixer_data,input signed[8:0] mixer_wave,input mixer_wv);
 localparam [511:0] T0=512'h4f2b000f002151000f0007052a6f000f00064a6000092a1400000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T0F=512'h4f2b000f007e7f000f0007052a6f000f00064a6000092a1400000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T0P=512'h4f2b000f006b51000f0007052a6f000f00064a6000092a1400000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T04=512'h256f4a60000f005b1d1f29000f003a0965264f2b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T064=512'h07056f4a60000f005b1d1f29000f003a0965264f2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T3TEST=512'h4a6012751e1c6d113b1b296f743a0968180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T1=512'h333e4937000d000705016944000d005b1d2852000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T2=512'h0301050950543e7061000d00483156000d0008060b6a20000d00464503040c050762170000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T3=512'h4f2b6d75595d133a1074735d133c3053430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] T4=512'h415f2d27000d00356702075000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] FX=512'h4b230e160022240e1600716f0e160035670e16004d6f0e160028520e0201010b0000000000000000000000000000000000000000000000000000000000000000;
 localparam [511:0] BYPASS=512'h4a603d64000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] TESTTITLE=512'h07052a6f4a60000d00333e7061000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] TESTINFO=512'h070564000d0003060879060509076217000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] TESTLEGEND=512'h595d0e36007a5d0e1600735d0e7b7c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] TESTHELP=512'h057b7c000d00073616000d00087d36000d0009681800000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] DELAYINFO=512'h262935670e0208010c064755000d004a603d64000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] FXBYPASS=512'h4b230d22240d26293d64000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 reg[15:0] font[0:4095];initial $readmemh("assets/font_zh16.hex",font);

 localparam[511:0] V_PRACTICE=512'h3c304f2b000d00808182838485228600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_READY=512'h06362e000d0009681800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_RUNNING=512'h063f15000d0009681800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_DONE=512'h5842000d0006362e000d000968180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_HEAD=512'h333e4f2b000d00808182838485228600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_INFO=512'h07052a6f8788000d00064a6000092a14000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_WAVE=512'h333e4937000d005b1d28520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_FFT=512'h333e7061000d000301050950000d0008060b6a200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_XY=512'h415f2d27000d00356702075000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_PADS=512'h4f2b898a000d001e1c8b6e1c8c8d8e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_ENV=512'h838f9091009293000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_ENVDEF=512'h94959697929300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_ENVUSER=512'h98999293000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_A=512'h9a6f8300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_D=512'h9b9c8f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_S=512'h9d9e9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_R=512'h9fa09100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_TITLE=512'ha1a2a3610e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_FREE=512'h5ba44f2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_CUSTOM=512'h5b7ba361000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_TWINKLE=512'h572f2f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_I0=512'h21510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_I1=512'h7e7f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] V_I2=512'h6b510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] S_OFF=512'h16ad0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] S_ON=512'h36ae0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] S_HOLD=512'haf3e3d64000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] S_TEST=512'h4a60b098000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] F0=512'h4b230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] F1=512'h22240000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] F2=512'h716f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] F3=512'h26290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] F4=512'h4d6f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] F5=512'h6fb10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_LOW=512'h6fb275b36f00c30203b56f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_MID=512'h6fb275b66f0001b56f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_HIGH=512'h6fb275726f00c20203b56f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_MIX=512'h6fb275b86d11b9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_CHART=512'h6f72753aa3610000020d030d04ba788c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_ALL=512'h5343757dbb6d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_KEY=512'h534375bc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_HINT=512'hbda975af3e3d640000beab75ac2ab697bf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_MANUAL=512'h33c03ac13d6412000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[511:0] P_NEAR=512'hbda93d64120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
 localparam[6:0] SID_T0=7'd1;
 localparam[6:0] SID_T0F=7'd2;
 localparam[6:0] SID_T0P=7'd3;
 localparam[6:0] SID_T04=7'd4;
 localparam[6:0] SID_T064=7'd5;
 localparam[6:0] SID_T3TEST=7'd6;
 localparam[6:0] SID_T1=7'd7;
 localparam[6:0] SID_T2=7'd8;
 localparam[6:0] SID_T3=7'd9;
 localparam[6:0] SID_T4=7'd10;
 localparam[6:0] SID_FX=7'd11;
 localparam[6:0] SID_BYPASS=7'd12;
 localparam[6:0] SID_TESTTITLE=7'd13;
 localparam[6:0] SID_TESTINFO=7'd14;
 localparam[6:0] SID_TESTLEGEND=7'd15;
 localparam[6:0] SID_TESTHELP=7'd16;
 localparam[6:0] SID_DELAYINFO=7'd17;
 localparam[6:0] SID_FXBYPASS=7'd18;
 localparam[6:0] SID_V_PRACTICE=7'd19;
 localparam[6:0] SID_V_READY=7'd20;
 localparam[6:0] SID_V_RUNNING=7'd21;
 localparam[6:0] SID_V_DONE=7'd22;
 localparam[6:0] SID_V_HEAD=7'd23;
 localparam[6:0] SID_V_INFO=7'd24;
 localparam[6:0] SID_V_WAVE=7'd25;
 localparam[6:0] SID_V_FFT=7'd26;
 localparam[6:0] SID_V_XY=7'd27;
 localparam[6:0] SID_V_PADS=7'd28;
 localparam[6:0] SID_V_ENV=7'd29;
 localparam[6:0] SID_V_ENVDEF=7'd30;
 localparam[6:0] SID_V_ENVUSER=7'd31;
 localparam[6:0] SID_V_A=7'd32;
 localparam[6:0] SID_V_D=7'd33;
 localparam[6:0] SID_V_S=7'd34;
 localparam[6:0] SID_V_R=7'd35;
 localparam[6:0] SID_V_TITLE=7'd36;
 localparam[6:0] SID_V_FREE=7'd37;
 localparam[6:0] SID_V_CUSTOM=7'd38;
 localparam[6:0] SID_V_TWINKLE=7'd39;
 localparam[6:0] SID_V_I0=7'd40;
 localparam[6:0] SID_V_I1=7'd41;
 localparam[6:0] SID_V_I2=7'd42;
 localparam[6:0] SID_S_OFF=7'd43;
 localparam[6:0] SID_S_ON=7'd44;
 localparam[6:0] SID_S_HOLD=7'd45;
 localparam[6:0] SID_S_TEST=7'd46;
 localparam[6:0] SID_F0=7'd47;
 localparam[6:0] SID_F1=7'd48;
 localparam[6:0] SID_F2=7'd49;
 localparam[6:0] SID_F3=7'd50;
 localparam[6:0] SID_F4=7'd51;
 localparam[6:0] SID_F5=7'd52;
 localparam[6:0] SID_P_LOW=7'd53;
 localparam[6:0] SID_P_MID=7'd54;
 localparam[6:0] SID_P_HIGH=7'd55;
 localparam[6:0] SID_P_MIX=7'd56;
 localparam[6:0] SID_P_CHART=7'd57;
 localparam[6:0] SID_P_ALL=7'd58;
 localparam[6:0] SID_P_KEY=7'd59;
 localparam[6:0] SID_P_HINT=7'd60;
 localparam[6:0] SID_P_MANUAL=7'd61;
 localparam[6:0] SID_P_NEAR=7'd62;
 // Stage 0 selects a compact string/offset descriptor; stage 1 resolves its character.
 // Reuses the original two stages, preserving RGB/sync/game-text alignment and latency.
 function[20:0] text_ref;input[6:0] sid;input[5:0] offset;
 begin text_ref={sid,offset,8'd0};end endfunction
 function[20:0] literal;input[7:0] value;
 begin literal={13'd0,value};end endfunction
 function[7:0] resolve_char;input[20:0] token;
 reg[5:0] offset;begin offset=token[13:8];
 case(token[20:14])
 SID_T0:resolve_char=T0[(63-offset)*8+:8];
 SID_T0F:resolve_char=T0F[(63-offset)*8+:8];
 SID_T0P:resolve_char=T0P[(63-offset)*8+:8];
 SID_T04:resolve_char=T04[(63-offset)*8+:8];
 SID_T064:resolve_char=T064[(63-offset)*8+:8];
 SID_T3TEST:resolve_char=T3TEST[(63-offset)*8+:8];
 SID_T1:resolve_char=T1[(63-offset)*8+:8];
 SID_T2:resolve_char=T2[(63-offset)*8+:8];
 SID_T3:resolve_char=T3[(63-offset)*8+:8];
 SID_T4:resolve_char=T4[(63-offset)*8+:8];
 SID_FX:resolve_char=FX[(63-offset)*8+:8];
 SID_BYPASS:resolve_char=BYPASS[(63-offset)*8+:8];
 SID_TESTTITLE:resolve_char=TESTTITLE[(63-offset)*8+:8];
 SID_TESTINFO:resolve_char=TESTINFO[(63-offset)*8+:8];
 SID_TESTLEGEND:resolve_char=TESTLEGEND[(63-offset)*8+:8];
 SID_TESTHELP:resolve_char=TESTHELP[(63-offset)*8+:8];
 SID_DELAYINFO:resolve_char=DELAYINFO[(63-offset)*8+:8];
 SID_FXBYPASS:resolve_char=FXBYPASS[(63-offset)*8+:8];
 SID_V_PRACTICE:resolve_char=V_PRACTICE[(63-offset)*8+:8];
 SID_V_READY:resolve_char=V_READY[(63-offset)*8+:8];
 SID_V_RUNNING:resolve_char=V_RUNNING[(63-offset)*8+:8];
 SID_V_DONE:resolve_char=V_DONE[(63-offset)*8+:8];
 SID_V_HEAD:resolve_char=V_HEAD[(63-offset)*8+:8];
 SID_V_INFO:resolve_char=V_INFO[(63-offset)*8+:8];
 SID_V_WAVE:resolve_char=V_WAVE[(63-offset)*8+:8];
 SID_V_FFT:resolve_char=V_FFT[(63-offset)*8+:8];
 SID_V_XY:resolve_char=V_XY[(63-offset)*8+:8];
 SID_V_PADS:resolve_char=V_PADS[(63-offset)*8+:8];
 SID_V_ENV:resolve_char=V_ENV[(63-offset)*8+:8];
 SID_V_ENVDEF:resolve_char=V_ENVDEF[(63-offset)*8+:8];
 SID_V_ENVUSER:resolve_char=V_ENVUSER[(63-offset)*8+:8];
 SID_V_A:resolve_char=V_A[(63-offset)*8+:8];
 SID_V_D:resolve_char=V_D[(63-offset)*8+:8];
 SID_V_S:resolve_char=V_S[(63-offset)*8+:8];
 SID_V_R:resolve_char=V_R[(63-offset)*8+:8];
 SID_V_TITLE:resolve_char=V_TITLE[(63-offset)*8+:8];
 SID_V_FREE:resolve_char=V_FREE[(63-offset)*8+:8];
 SID_V_CUSTOM:resolve_char=V_CUSTOM[(63-offset)*8+:8];
 SID_V_TWINKLE:resolve_char=V_TWINKLE[(63-offset)*8+:8];
 SID_V_I0:resolve_char=V_I0[(63-offset)*8+:8];
 SID_V_I1:resolve_char=V_I1[(63-offset)*8+:8];
 SID_V_I2:resolve_char=V_I2[(63-offset)*8+:8];
 SID_S_OFF:resolve_char=S_OFF[(63-offset)*8+:8];
 SID_S_ON:resolve_char=S_ON[(63-offset)*8+:8];
 SID_S_HOLD:resolve_char=S_HOLD[(63-offset)*8+:8];
 SID_S_TEST:resolve_char=S_TEST[(63-offset)*8+:8];
 SID_F0:resolve_char=F0[(63-offset)*8+:8];
 SID_F1:resolve_char=F1[(63-offset)*8+:8];
 SID_F2:resolve_char=F2[(63-offset)*8+:8];
 SID_F3:resolve_char=F3[(63-offset)*8+:8];
 SID_F4:resolve_char=F4[(63-offset)*8+:8];
 SID_F5:resolve_char=F5[(63-offset)*8+:8];
 SID_P_LOW:resolve_char=P_LOW[(63-offset)*8+:8];
 SID_P_MID:resolve_char=P_MID[(63-offset)*8+:8];
 SID_P_HIGH:resolve_char=P_HIGH[(63-offset)*8+:8];
 SID_P_MIX:resolve_char=P_MIX[(63-offset)*8+:8];
 SID_P_CHART:resolve_char=P_CHART[(63-offset)*8+:8];
 SID_P_ALL:resolve_char=P_ALL[(63-offset)*8+:8];
 SID_P_KEY:resolve_char=P_KEY[(63-offset)*8+:8];
 SID_P_HINT:resolve_char=P_HINT[(63-offset)*8+:8];
 SID_P_MANUAL:resolve_char=P_MANUAL[(63-offset)*8+:8];
 SID_P_NEAR:resolve_char=P_NEAR[(63-offset)*8+:8];
 default:resolve_char=token[7:0];
 endcase end endfunction
 wire[9:0] footer_y0=(game[30] || game[127])?10'd688:10'd624;
 wire pitch_row=!game[127] && (game[30]?(y>=152 && y<168 && x>=320 && x<992):(y>=96 && y<112 && x>=128 && x<768));
 wire hint_row=!game[30] && !game[127] && y>=688 && y<704 && x>=512 && x<1248;
 wire[10:0] pitch_x=x-(game[30]?11'd320:11'd128),hint_x=x-11'd512;
 reg[2:0] fx_cell;reg[10:0] fx_x;reg fx_enabled;reg[1:0] fx_status;
 reg[6:0] fx_name,fx_word,pitch_word;reg[1:0] display_octave;
 wire[3:0] pitch_target=pitch_status[21:18];
 wire[15:0] pitch_modes=pitch_status[17:2];
 wire mixed_pitch=pitch_modes!={8{pitch_modes[1:0]}};
 // Frame-held status is decoded independently of the pixel-coordinate mux.
 reg[1:0] effect_state[0:4];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin effect_state[0]<=0;effect_state[1]<=0;effect_state[2]<=0;effect_state[3]<=0;effect_state[4]<=0;end
 else begin
 effect_state[0]<=game[127]?3:game[117]?2:game[118]?1:0;
 effect_state[1]<=game[127]?3:game[117]?2:game[119]?1:0;
 effect_state[2]<=game[127]?3:game[123]?1:0;
 effect_state[3]<=game[127]?3:game[117]?2:game[124]?1:0;
 effect_state[4]<=game[127]?3:game[122]?1:0;
 end
 always @*begin
  if(x<256)begin fx_cell=0;fx_x=x-11'd64;end
  else if(x<448)begin fx_cell=1;fx_x=x-11'd256;end
  else if(x<640)begin fx_cell=2;fx_x=x-11'd448;end
  else if(x<832)begin fx_cell=3;fx_x=x-11'd640;end
  else if(x<1024)begin fx_cell=4;fx_x=x-11'd832;end
  else begin fx_cell=5;fx_x=x-11'd1024;end
  fx_name=SID_F0;fx_enabled=0;
  case(fx_cell)
  0:begin fx_name=SID_F0;fx_enabled=game[118];end
  1:begin fx_name=SID_F1;fx_enabled=game[119];end
  2:begin fx_name=SID_F2;fx_enabled=game[123];end
  3:begin fx_name=SID_F3;fx_enabled=game[124];end
  4:begin fx_name=SID_F4;fx_enabled=game[122];end
  5:begin fx_name=SID_F5;fx_enabled=1;end
  endcase
  fx_status=fx_cell<5?effect_state[fx_cell]:game[127]?2'd3:2'd1;
  case(fx_status)0:fx_word=SID_S_OFF;1:fx_word=SID_S_ON;2:fx_word=SID_S_HOLD;default:fx_word=SID_S_TEST;endcase
  display_octave=pitch_target<8?pitch_modes[pitch_target*2+:2]:pitch_modes[1:0];
  pitch_word=(game[30] || game[100])?SID_P_CHART:pitch_target==8 && mixed_pitch?SID_P_MIX:display_octave==1?SID_P_LOW:display_octave==2?SID_P_HIGH:SID_P_MID;
  // Uploaded event durations are authoritative; built-in speed keys do not apply.

 end
 wire[10:0] header_lx=x-11'd240,info_lx=x-11'd560;
 wire[9:0] header_ly=y-10'd16,tab_ly=y-10'd76,pad_ly=y-10'd580;
 wire[10:0] name_label_x=x-11'd400,name_text_x=x-11'd560;
 wire gt;wire[3:0] gr;wire[3:0] gc;wire[7:0] gl;
 video_game_text game_text(clk,rst_n,x,y,game,gt,gr,gc,gl);
 wire mix_show=mixer_data[33] && !game[30] && !game[127];
 wire[23:0] mix_bg,mix_color;wire mix_text;wire[3:0] mix_row,mix_col;
 wire[21:0] mix_descriptor;reg[21:0] mix_descriptor0;reg mix_active0,mix_active1;wire[7:0] mix_char1;
 video_mixer_desc mix_view(x,y,mixer_data,mixer_wave,mixer_wv,mix_bg,mix_color,mix_text,mix_row,mix_col,mix_descriptor);
 video_mixer_char mix_lookup(clk,mix_descriptor0,mix_char1);
 // Unused by hardware output; retained solely for combinational equivalence probes.
 // synthesis translate_off
 wire[7:0] mix_letter;
 video_mixer mix_debug(.x(x),.y(y),.data(mixer_data),.wave(mixer_wave),.wave_valid(mixer_wv),.letter(mix_letter));
 // synthesis translate_on
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin mix_descriptor0<=0;mix_active0<=0;mix_active1<=0;end
 else begin mix_descriptor0<=mix_descriptor;mix_active0<=mix_show;mix_active1<=mix_active0;end
 reg text_on;reg[5:0] index;reg[3:0] row;reg[3:0] col;reg[20:0] token;
 // synthesis translate_off
 wire[7:0] letter=mix_show?mix_letter:resolve_char(token);
 // synthesis translate_on
 wire[10:0] xy_label_x=x-11'd896;
 wire[10:0] local_x=x-11'd128;
 wire[10:0] footer_x=x-11'd64;
 wire[6:0] percent=game[116:110];
 reg[3:0] tens,ones;reg[6:0] remainder;
 always @*begin
  tens=0;remainder=percent;
  if(percent>=100)begin tens=0;remainder=0;end
  else if(percent>=90)begin tens=9;remainder=percent-7'd90;end
  else if(percent>=80)begin tens=8;remainder=percent-7'd80;end
  else if(percent>=70)begin tens=7;remainder=percent-7'd70;end
  else if(percent>=60)begin tens=6;remainder=percent-7'd60;end
  else if(percent>=50)begin tens=5;remainder=percent-7'd50;end
  else if(percent>=40)begin tens=4;remainder=percent-7'd40;end
  else if(percent>=30)begin tens=3;remainder=percent-7'd30;end
  else if(percent>=20)begin tens=2;remainder=percent-7'd20;end
  else if(percent>=10)begin tens=1;remainder=percent-7'd10;end
  ones=remainder[3:0];
 end
 reg[23:0] text_color;wire footer=(game[30] || game[127])?(y>=688 && y<720):(y>=624 && y<656);
 wire delay_row=game[127] && y>=64 && y<80 && x>=128 && x<768;

 always @*begin
  text_on=0;index=0;row=0;col=0;token=literal(8'd0);text_color=(game[30] || game[127])?24'he1edf7:24'h123656;
  if(x>=128 && x<1152 && y>=16 && y<48)begin
   text_on=1;index={1'b0,local_x[9:5]};row=y[4:1]-4'd8;col=local_x[4:1];token=game[127]  ?  (game[126]  ?  text_ref(SID_T064,index) : text_ref(SID_T04,index)) : (game[120]  ?  text_ref(SID_T0P,index) : game[121]  ?  text_ref(SID_T0F,index) : text_ref(SID_T0,index));
  end else if(x>=128 && x<1152)begin
   index=local_x[9:4];col=local_x[3:0];
   if(y>=96 && y<112)begin text_on=1;row=y[3:0];token=text_ref(SID_T1,index);end
   if(y>=368 && y<384)begin text_on=1;row=y[3:0];token=text_ref(SID_T2,index);end
   if(y>=616 && y<632)begin text_on=1;row=y[3:0]-4'd8;token=game[127]  ?  text_ref(SID_T3TEST,index) : text_ref(SID_T3,index);end
  end
  if(x>=896 && x<1152 && y>=72 && y<88)begin
   text_on=1;index={2'b0,xy_label_x[7:4]};col=xy_label_x[3:0];row=y[3:0]-4'd8;
   token=text_ref(SID_T4,index);
  end

  if(!game[30] && !game[127])begin
   text_on=0;index=local_x[9:4];col=local_x[3:0];row=y[3:0];
   if(x>=240 && x<1264 && y>=16 && y<48)begin text_on=1;index=header_lx[10:5];col=header_lx[4:1];row=header_ly[4:1];token=game[100]?text_ref(SID_V_PRACTICE,index):text_ref(SID_V_HEAD,index);end
   if(x>=400 && x<560 && y>=48 && y<64)begin text_on=1;index=name_label_x[9:4];col=name_label_x[3:0];row=y[3:0];token=text_ref(SID_V_TITLE,index);end
   if(x>=560 && x<816 && y>=48 && y<64)begin text_on=1;index=name_text_x[9:4];col=name_text_x[3:0];row=y[3:0];token=game[104]?text_ref(SID_V_CUSTOM,index):text_ref(SID_V_TWINKLE,index);end
   if(x>=128 && x<512 && y>=76 && y<92)begin text_on=1;index={3'd0,local_x[6:4]};col=local_x[3:0];row=tab_ly[3:0];token=x<256?text_ref(SID_V_I0,index):x<384?text_ref(SID_V_I1,index):text_ref(SID_V_I2,index);end
   if(x>=560 && x<1168 && y>=76 && y<92)begin text_on=1;index=info_lx[9:4];col=info_lx[3:0];row=tab_ly[3:0];token=game[100]?(game[32]?text_ref(SID_V_DONE,index):game[31]?text_ref(SID_V_RUNNING,index):text_ref(SID_V_READY,index)):text_ref(SID_V_INFO,index);end
   if(x>=128 && x<768 && y>=112 && y<128)begin text_on=1;token=text_ref(SID_V_WAVE,index);end
   if(x>=896 && x<1152 && y>=96 && y<112)begin text_on=1;index=xy_label_x[7:4];col=xy_label_x[3:0];token=text_ref(SID_V_XY,index);end
   if(x>=128 && x<1152 && y>=368 && y<384)begin text_on=1;token=text_ref(SID_V_FFT,index);end
   if(x>=128 && x<1152 && y>=580 && y<596 && local_x[6:0]<16)begin text_on=1;row=pad_ly[3:0];token=literal(8'd2+{5'd0,local_x[9:7]});end
   if(x>=128 && x<1152 && y>=656 && y<672)begin
    text_on=1;index={2'd0,local_x[7:4]};col=local_x[3:0];row=y[3:0];
    token=x<384?text_ref(SID_V_A,index):x<640?text_ref(SID_V_D,index):x<896?text_ref(SID_V_S,index):text_ref(SID_V_R,index);
   end
   if(x>=128 && x<768 && y>=688 && y<704)begin text_on=1;token=user_envelope?text_ref(SID_V_ENVUSER,index):text_ref(SID_V_ENVDEF,index);end
  end
  if(x>=64 && x<1216 && footer)begin
   text_on=1;index=fx_x[9:4];col=fx_x[3:0];row=y[3:0];
   token=y<footer_y0+16?text_ref(fx_name,index):text_ref(fx_word,index);
   if(y>=footer_y0+16)begin
    case(fx_status)
     0:text_color=game[30]||game[127]?24'hb3c0cf:24'h516477;
     1:text_color=game[30]||game[127]?24'h32edb0:24'h007b59;
     2:text_color=game[30]||game[127]?24'hffcb55:24'ha45b00;
     3:text_color=game[30]||game[127]?24'hffcb55:24'ha45b00;
    endcase
    if(fx_cell==5)begin
     case(index)
     0:token=literal(percent>=100?8'd2:8'd0);
     1:token=literal(8'd1+tens);
     2:token=literal(8'd1+ones);
     3:token=literal(8'd11);
     default:token=literal(8'd0);
     endcase
    end
   end
  end
  if(pitch_row)begin
   text_on=1;index=pitch_x[9:4];col=pitch_x[3:0];row=game[30]?y[3:0]-4'd8:y[3:0];
   token=(((game[30] || game[100]) && game[104] && index>=8)?literal(8'd0):text_ref(pitch_word,index));
   if(!game[30] && !game[100] && index>=20)begin
    token=pitch_target==8?text_ref(SID_P_ALL,index-6'd20):text_ref(SID_P_KEY,index-6'd20);
    if(pitch_target<8 && index==24)token=literal(8'd2+{4'd0,pitch_target});
   end
  end
  if(hint_row)begin
   text_on=1;index=hint_x[9:4];col=hint_x[3:0];row=y[3:0];
   token=pitch_status[0]?text_ref(SID_P_MANUAL,index):pitch_status[1]?text_ref(SID_P_NEAR,index):text_ref(SID_P_HINT,index);
   if(pitch_status[1:0]!=0)text_color=24'ha45b00;
  end

  if(game[127] && game[126] && y<688)begin
   text_on=0;
   if(x>=128 && x<1152)begin
    index=local_x[9:4];col=local_x[3:0];row=y[3:0];
    if(y>=16 && y<48)begin text_on=1;index={1'b0,local_x[9:5]};row=y[4:1]-4'd8;col=local_x[4:1];token=text_ref(SID_TESTTITLE,index);end
    if(y>=96 && y<112)begin text_on=1;token=text_ref(SID_TESTINFO,index);end
    if(y>=112 && y<128)begin text_on=1;token=text_ref(SID_TESTLEGEND,index);end
    if(y>=656 && y<672)begin text_on=1;token=text_ref(SID_TESTHELP,index);end
   end
  end

  if(delay_row && (game[30] || game[127]))begin
   text_on=1;index=local_x[9:4];col=local_x[3:0];row=y[3:0];
   token=text_ref(SID_DELAYINFO,index);
   if(!game[127])begin
    if(game[117])token=text_ref(SID_FXBYPASS,index);
    else if(index>=13)token=literal(8'd0);
   end
   text_color=24'haabbd0;
  end
  if(mix_show)begin text_on=mix_text;row=mix_row;col=mix_col;token=literal(8'd0);text_color=mix_color;end
 end

 reg[23:0] rgb0,rgb1;reg[2:0] sync0,sync1;
 reg[29:0] normal0;
 reg[7:0] char_rom[0:4095];initial $readmemh("tb/reference_label_strings.hex",char_rom);
 reg[7:0] char_q,literal_q;reg literal_select;reg[8:0] normal_meta;
 wire[16:0] normal1={normal_meta,mix_active1?mix_char1:(literal_select?literal_q:char_q)};
 always @(posedge clk)char_q<=char_rom[normal0[19:8]];
reg game0,game1;reg footer0,footer1;reg[23:0] color0,color1,color_d;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin rgb0<=0;rgb1<=0;sync0<=0;sync1<=0;normal0<=0;normal_meta<=0;literal_q<=0;literal_select<=1;game0<=0;game1<=0;footer0<=0;footer1<=0;color0<=0;color1<=0;end
 else begin
 rgb0<=mix_show ? mix_bg : footer ? ((game[30] || game[127])?24'h101e30:24'heaf3fa) : rgb_in;rgb1<=rgb0;color0<=text_color;color1<=color0;sync0<={hi,vi,di};sync1<=sync0;
 normal0<={text_on,row,col,token};normal_meta<=normal0[29:21];literal_select<=normal0[20:14]==0;literal_q<=normal0[7:0];game0<=game[30];game1<=game0;footer0<=footer || delay_row || pitch_row || hint_row;footer1<=footer0;
 end
 wire use_game=game1 && !footer1;
 wire ft=use_game ? gt:normal1[16];wire[3:0] fr=use_game ? gr:normal1[15:12];
 wire[3:0] fc=use_game ? gc:normal1[11 : 8];wire[7:0] fl=use_game ? gl:normal1[7:0];
 reg[15:0] glyph;reg[3:0] col_d;reg text_d;reg[23:0] rgb_d;reg h_d,v_d,d_d;
 always @(posedge clk)glyph<=font[{fl,fr}];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin color_d<=0;col_d<=0;text_d<=0;rgb_d<=0;h_d<=0;v_d<=0;d_d<=0;ho<=0;vo<=0;do_<=0;rgb_out<=0;end
 else begin
  color_d<=use_game ? 24'he1edf7:color1;col_d<=fc;text_d<=ft;rgb_d<=rgb1;h_d<=sync1[2];v_d<=sync1[1];d_d<=sync1[0];
  ho<=h_d;vo<=v_d;do_<=d_d;rgb_out<=(text_d && glyph[15-col_d]) ? color_d :
   (text_d && ((col_d!=0 && glyph[16-col_d]) || (col_d!=15 && glyph[14-col_d]))) ?
   {({1'b0,color_d[23:17]}+{1'b0,rgb_d[23:17]}),({1'b0,color_d[15:9]}+{1'b0,rgb_d[15:9]}),({1'b0,color_d[7:1]}+{1'b0,rgb_d[7:1]})} : rgb_d;
 end
endmodule



