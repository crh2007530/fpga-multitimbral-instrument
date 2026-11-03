`timescale 1ns/1ps
// Musical onset/decay is applied by the shared timbre engine. This envelope
// supplies only the note gate and release. Diagnostic ADSR remains exact.
module instrument_env_v18_reference #(parameter THIRD_TIMBRE=0)(input wire clk,rst_n,sample_ce,note_on,note_off,flute,diagnostic,
 output wire[15:0] level,output wire active,input wire epiano);
 generate if(!THIRD_TIMBRE)begin:legacy
 instrument_env_legacy #(.THIRD_TIMBRE(0)) original(clk,rst_n,sample_ce,note_on,note_off,flute,diagnostic,level,active,epiano);
 end else begin:musical
 localparam IDLE=0,ATTACK=1,DECAY=2,SUSTAIN=3,RELEASE=4;
 reg[2:0]state,divider;reg[15:0]amplitude;reg test,slow_release;
 wire[15:0] release_step=slow_release?((amplitude>>9)+1):((amplitude>>8)+1);
 assign level=amplitude;assign active=state!=IDLE;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin state<=IDLE;divider<=0;amplitude<=0;test<=0;slow_release<=0;end
 else if(note_on)begin
 test<=diagnostic;slow_release<=epiano||flute;divider<=0;state<=diagnostic?ATTACK:SUSTAIN;
 if(!diagnostic)amplitude<=32767;
 end else if(note_off && active)state<=RELEASE;
 else if(sample_ce)begin
 divider<=divider+1'b1;
 case(state)
 IDLE:amplitude<=0;
 ATTACK:if(amplitude>=32630)begin amplitude<=32767;state<=DECAY;end else amplitude<=amplitude+16'd137;
 DECAY:if(amplitude<=19667)begin amplitude<=19660;state<=SUSTAIN;end else amplitude<=amplitude-16'd7;
 SUSTAIN:amplitude<=test?16'd19660:16'd32767;
 RELEASE:if(test)begin
 if(amplitude<=9)begin amplitude<=0;state<=IDLE;end else amplitude<=amplitude-16'd9;
 end else if(divider==0)begin
 if(amplitude<=release_step)begin amplitude<=0;state<=IDLE;end else amplitude<=amplitude-release_step;
 end
 default:begin state<=IDLE;amplitude<=0;end
 endcase
 end
 end endgenerate
endmodule
