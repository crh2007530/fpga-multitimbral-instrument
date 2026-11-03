`timescale 1ns/1ps
// 32 independent expression states; one pipelined arithmetic/DSP lane.
// Initiation interval = 1 voice/clock, all results in 36 clocks.
// NEXT-sample phase updates finish by request+37; audio samples retain
// their original request-time DDS address and I2S publication schedule.
module reference_pitch_v40 #(parameter CUSTOM_MAP=0)(input clk,rst_n,sample_ce,glide,vibrato,
 input[1023:0] targets,input signed[4:0] lfo,
 output reg valid,output reg[4:0] index,output reg[31:0] increment,
 output wire busy,output reg overrun,input map_enabled,input[55:0] keymap,input[15:0] modes);
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
  if(launch)begin issued<=issued+1'b1;i0<=issued[4:0];t0<=captured[issued[4:0]*32+:32];init0<=initialized[issued[4:0]];end
  if(pipe[0])begin i1<=i0;t1<=target0;c1<=c0;init1<=init0;
   diff1<={1'b0,target0}-{1'b0,c0};b1<=(g && init0) ? c0:target0;end
  if(pipe[1])begin i2<=i1;t2<=t1;c2<=c1;init2<=init1;b2<=b1;
   distance2<=diff1[32]  ?  -diff1[31:0] : diff1[31:0];negative2<=diff1[32];end
  if(pipe[2])begin initialized[i2]<=1;i3<=i2;b3<=b2;delta3<=b2[31:10]*magnitude;end
  if(pipe[3])begin index<=i3;increment<=v  ?  b3+signed_delta3 : b3;if(i3==31)active<=0;end
 end
endmodule
