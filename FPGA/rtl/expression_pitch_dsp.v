`timescale 1ns/1ps
// Exact fixed-width replacement: share subtract/add paths and map LFO multiply to DSP.
module expression_pitch_dsp(input wire clk,rst_n,sample_ce,glide,vibrato,
 input wire[31:0] target,input wire signed[4:0] lfo,output wire[31:0] phase_inc);
 reg[31:0] current;reg initialized;
 wire[32:0] difference={1'b0,target}-{1'b0,current};
 wire negative=difference[32];
 wire[31:0] distance=negative ? -difference[31:0] : difference[31:0];
 wire[31:0] step_size=distance>>9;
 wire[31:0] signed_step=negative ? -step_size : step_size;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin current<=0;initialized<=0;end
 else if(sample_ce)begin
  initialized<=1;
  if(!glide || !initialized || distance<512)current<=target;
  else current<=current+signed_step;
 end
 wire[31:0] base=(glide && initialized)?current:target;
 wire[3:0] magnitude=lfo[4] ? 4'd0-lfo[3:0] : lfo[3:0];
 wire[25:0] delta=base[31:10]*magnitude;
 wire[31:0] signed_delta=lfo[4] ? -{6'd0,delta} : {6'd0,delta};
 assign phase_inc=vibrato ? base+signed_delta : base;
endmodule
