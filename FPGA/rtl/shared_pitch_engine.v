`timescale 1ns/1ps
// 32 independent expression states; one pipelined arithmetic/DSP lane.
// Initiation interval = 1 voice/clock, all results in 36 clocks.
// NEXT-sample phase updates finish by request+37; audio samples retain
// their original request-time DDS address and I2S publication schedule.
module shared_pitch_engine #(parameter CUSTOM_MAP=0,COMPACT_TARGETS=0)(input clk,rst_n,sample_ce,glide,vibrato,
 input[1023:0] targets,input signed[4:0] lfo,
 output reg valid,output reg[4:0] index,output reg[31:0] increment,
 output wire busy,output reg overrun,input map_enabled,input[55:0] keymap,input[15:0] modes,input diagnostic_mode,all_test);
 // Decode per-voice targets locally from 18 captured control bits, instead
 // of distributing and selecting a 1024-bit captured target frame.
 reg[15:0] target_modes;reg target_test,target_all;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin target_modes<=0;target_test<=0;target_all<=0;end
 else if(sample_ce && !active)begin target_modes<=modes;target_test<=diagnostic_mode;target_all<=all_test;end
function[31:0] chord_target;input[4:0] index;begin case(index)
5'd0:chord_target=32'd46774041;
5'd1:chord_target=32'd52502086;
5'd2:chord_target=32'd58931599;
5'd3:chord_target=32'd62435854;
5'd4:chord_target=32'd70081876;
5'd5:chord_target=32'd78664247;
5'd6:chord_target=32'd88297631;
5'd7:chord_target=32'd93548082;
5'd8:chord_target=32'd58931599;
5'd9:chord_target=32'd66148483;
5'd10:chord_target=32'd74249162;
5'd11:chord_target=32'd78664247;
5'd12:chord_target=32'd88297631;
5'd13:chord_target=32'd99110741;
5'd14:chord_target=32'd111248044;
5'd15:chord_target=32'd117863198;
5'd16:chord_target=32'd70081877;
5'd17:chord_target=32'd78664247;
5'd18:chord_target=32'd88297632;
5'd19:chord_target=32'd93548082;
5'd20:chord_target=32'd105004171;
5'd21:chord_target=32'd117863198;
5'd22:chord_target=32'd132296965;
5'd23:chord_target=32'd140163753;
5'd24:chord_target=32'd93548082;
5'd25:chord_target=32'd105004172;
5'd26:chord_target=32'd117863198;
5'd27:chord_target=32'd124871708;
5'd28:chord_target=32'd140163752;
5'd29:chord_target=32'd157328494;
5'd30:chord_target=32'd176595262;
5'd31:chord_target=32'd187096164;
default:chord_target=0;endcase end endfunction
function[31:0] diagnostic_target;input[4:0] index;begin case(index)
5'd0:diagnostic_target=32'd22973536;
5'd1:diagnostic_target=32'd30393004;
5'd2:diagnostic_target=32'd37812473;
5'd3:diagnostic_target=32'd45231942;
5'd4:diagnostic_target=32'd52651410;
5'd5:diagnostic_target=32'd60070879;
5'd6:diagnostic_target=32'd67490348;
5'd7:diagnostic_target=32'd74909817;
5'd8:diagnostic_target=32'd82329285;
5'd9:diagnostic_target=32'd89748754;
5'd10:diagnostic_target=32'd97168223;
5'd11:diagnostic_target=32'd104587691;
5'd12:diagnostic_target=32'd112007160;
5'd13:diagnostic_target=32'd119426629;
5'd14:diagnostic_target=32'd126846098;
5'd15:diagnostic_target=32'd134265566;
5'd16:diagnostic_target=32'd141685035;
5'd17:diagnostic_target=32'd149104504;
5'd18:diagnostic_target=32'd156523972;
5'd19:diagnostic_target=32'd163943441;
5'd20:diagnostic_target=32'd171362910;
5'd21:diagnostic_target=32'd178782379;
5'd22:diagnostic_target=32'd186201847;
5'd23:diagnostic_target=32'd193621316;
5'd24:diagnostic_target=32'd201040785;
5'd25:diagnostic_target=32'd208460253;
5'd26:diagnostic_target=32'd215879722;
5'd27:diagnostic_target=32'd223299191;
5'd28:diagnostic_target=32'd230718659;
5'd29:diagnostic_target=32'd238138128;
5'd30:diagnostic_target=32'd245557597;
5'd31:diagnostic_target=32'd252977066;
default:diagnostic_target=0;endcase end endfunction

 wire[1:0] target_octave=target_modes[issued[2:0]*2+:2];
 wire[31:0] chord_value=chord_target(issued[4:0]);
 wire[31:0] compact_target=target_test?(target_all?diagnostic_target(issued[4:0]):chord_target({2'd0,issued[2:0]})):
 target_octave==1?(chord_value>>1):target_octave==2?(chord_value<<1):chord_value;
 reg[31:0] current[0:31];reg[31:0] initialized;
 reg[1023:0] captured;reg g,v;reg signed[4:0] lf;
 reg active;reg[5:0] issued;reg[3:0] pipe;
 reg[4:0] i0,i1,i2,i3;
 reg[31:0] c0,c1,c2,t0,t1,t2,b1,b2,b3;
 reg init0,init1,init2;reg[32:0] diff1;
 reg[31:0] distance2;reg negative2;reg[25:0] delta3;
 wire launch=active && issued<32;
 wire[31:0] target0;
 generate if(CUSTOM_MAP)begin: custom
  reg enabled;reg[55:0] notes;reg[15:0] octaves;
  reg[31:0] rom[0:127];reg[31:0] mapped;
  initial $readmemh("assets/midi_inc_128.hex",rom);
  reg signed[9:0] note;reg[6:0] address;
  always @*begin
   note=$signed({3'd0,notes[issued[2:0]*7+:7]});
   case(issued[4:3])1:note=note+10'sd4;2:note=note+10'sd7;3:note=note+10'sd12;default:;endcase
   case(octaves[issued[2:0]*2+:2])1:note=note-10'sd12;2:note=note+10'sd12;default:;endcase
   address=note<0 ? 0:note>127 ? 127:note[6:0];
  end
  always @(posedge clk)if(launch)mapped<=rom[address];
  always @(posedge clk or negedge rst_n)
   if(!rst_n)begin enabled<=0;notes<=0;octaves<=0;end
   else if(sample_ce && !active)begin enabled<=map_enabled;notes<=keymap;octaves<=modes;end
  assign target0=enabled ? mapped:t0;
 end else begin assign target0=t0;end endgenerate
 wire[3:0] magnitude=lf[4]  ?  4'd0-lf[3:0] : lf[3:0];
 wire[31:0] step2=distance2>>9;
 wire[31:0] signed_step2=negative2  ?  -step2 : step2;
 wire[31:0] signed_delta3=lf[4]  ?  -{6'd0,delta3} : {6'd0,delta3};
 assign busy=active;
 // One synchronous read + one write, no reset on RAM contents.
 always @(posedge clk)begin
  if(launch)c0<=current[issued[4:0]];
  if(pipe[2])current[i2]<=(!g || !init2 || distance2<512) ? t2:c2+signed_step2;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  initialized<=0;captured<=0;g<=0;v<=0;lf<=0;active<=0;issued<=0;pipe<=0;
  i0<=0;i1<=0;i2<=0;i3<=0;c1<=0;c2<=0;t0<=0;t1<=0;t2<=0;
  b1<=0;b2<=0;b3<=0;init0<=0;init1<=0;init2<=0;diff1<=0;
  distance2<=0;negative2<=0;delta3<=0;valid<=0;index<=0;increment<=0;overrun<=0;
 end else begin
  pipe<={pipe[2:0],launch};valid<=pipe[3];
  if(sample_ce)begin
   if(active)overrun<=1;
   else begin captured<=targets;g<=glide;v<=vibrato;lf<=lfo;active<=1;issued<=0;end
  end
  if(launch)begin issued<=issued+1'b1;i0<=issued[4:0];t0<=COMPACT_TARGETS?compact_target:captured[issued[4:0]*32+:32];init0<=initialized[issued[4:0]];end
  if(pipe[0])begin i1<=i0;t1<=target0;c1<=c0;init1<=init0;
   diff1<={1'b0,target0}-{1'b0,c0};b1<=(g && init0) ? c0:target0;end
  if(pipe[1])begin i2<=i1;t2<=t1;c2<=c1;init2<=init1;b2<=b1;
   distance2<=diff1[32]  ?  -diff1[31:0] : diff1[31:0];negative2<=diff1[32];end
  if(pipe[2])begin initialized[i2]<=1;i3<=i2;b3<=b2;delta3<=b2[31:10]*magnitude;end
  if(pipe[3])begin index<=i3;increment<=v  ?  b3+signed_delta3 : b3;if(i3==31)active<=0;end
 end
endmodule
