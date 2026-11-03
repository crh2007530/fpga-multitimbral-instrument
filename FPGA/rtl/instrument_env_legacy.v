`timescale 1ns/1ps
// One shared 16-bit envelope adder per voice; two musical presets and legacy diagnostics.
module instrument_env_legacy #(parameter THIRD_TIMBRE=0)(input wire clk,rst_n,sample_ce,note_on,note_off,flute,diagnostic,
 output reg[15:0] level,output wire active,input wire epiano);
 localparam IDLE=0,ATTACK=1,DECAY=2,SUSTAIN=3,RELEASE=4;
 reg[2:0] state;reg[1:0] kind;reg test;
 wire piano=kind==2;wire wind=kind==1;wire reed=THIRD_TIMBRE && kind==0;
 wire[3:0] piano_step={2'b0,level[14:13]}+4'd1;
 reg[2:0] piano_tail_div;
 reg[15:0] delta;reg at_peak,at_sustain,at_zero;
 wire[5:0] pluck_step={1'b0,level[14:10]}+6'd1;
 wire[15:0] next_level=level+delta;
 assign active=state!=IDLE;
 always @*begin
 delta=0;at_peak=0;at_sustain=0;at_zero=0;
 case(state)
 ATTACK:begin
 delta=test?16'd137:piano?16'd1024:wind?16'd256:reed?16'd512:16'd4096;
 at_peak=test?(level>=32630):piano?(level>=31743):wind?(level>=32511):reed?(level>=32255):(level>=28671);
 end
 DECAY:begin
 delta=test?16'hfff9:piano?(~{12'd0,piano_step}+16'd1):wind?16'hfff0:reed?16'hffe0:~{10'd0,pluck_step}+16'd1;
 at_sustain=test?(level<=19667):(piano ? level<=8196 : (wind && level<=24592) || (reed && level<=28704));
 at_zero=!test && ((piano && level<=1) || (!reed && kind==0 && level<=1));
 end
 RELEASE:begin
 delta=test?16'hfff7:piano?16'hfff0:wind?16'hffc0:reed?16'hff80:16'hff00;
 at_zero=test?(level<=9):piano?(level<=16):wind?(level<=64):reed?(level<=128):(level<=256);
 end
 default:;
 endcase end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin state<=IDLE;kind<=0;test<=0;level<=0;piano_tail_div<=0;end
 else if(note_on)begin kind<=(THIRD_TIMBRE && epiano)?2'd2:{1'b0,flute};test<=diagnostic;piano_tail_div<=0;state<=ATTACK;if(!diagnostic)level<=0;end
 else if(note_off && active)state<=RELEASE;
 else if(sample_ce)case(state)
 IDLE:level<=0;
 ATTACK:if(at_peak)begin level<=32767;state<=DECAY;end else level<=next_level;
 DECAY:if(at_sustain)begin level<=test?19660:piano?8192:reed?28672:24576;state<=SUSTAIN;end
 else if(at_zero)begin level<=0;state<=IDLE;end else level<=next_level;
 SUSTAIN:if(piano && !test)begin
  piano_tail_div<=piano_tail_div+1'b1;
  if(piano_tail_div==7)begin
   if(level<=1)begin level<=0;state<=IDLE;end
   else level<=level-1'b1;
  end
 end else level<=test?19660:reed?28672:24576;
 RELEASE:if(at_zero)begin level<=0;state<=IDLE;end else level<=next_level;
 default:begin level<=0;state<=IDLE;end
 endcase
 endmodule
