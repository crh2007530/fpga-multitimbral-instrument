`timescale 1ns/1ps
// Four chord-degree onset groups. Octave partners retain independent voices.
// One sweep per pressure attack / optical re-trigger; no periodic auto-repeat.
// The first group never gates the base pad's independent ADC watchdog.
module guitar_auto_strum #(parameter integer GAP_SAMPLES=576)(
 input clk,rst_n,sample_ce,enable,input[7:0] pad_held,
 output wire[31:0] groups);
 localparam CW=GAP_SAMPLES<2?1:$clog2(GAP_SAMPLES);
 reg[CW-1:0] age[0:7];reg[1:0] stage[0:7];
 genvar p;
 generate for(p=0;p<8;p=p+1)begin:pad
  always @(posedge clk or negedge rst_n)
  if(!rst_n)begin age[p]<=0;stage[p]<=0;end
  else if(!enable || !pad_held[p])begin age[p]<=0;stage[p]<=0;end
  else if(sample_ce && stage[p]!=3)begin
   if(age[p]==GAP_SAMPLES-1)begin age[p]<=0;stage[p]<=stage[p]+1'b1;end
   else age[p]<=age[p]+1'b1;
  end
  assign groups[p]=1'b1;
  assign groups[8+p]=!enable || (pad_held[p] && stage[p]>=1);
  assign groups[16+p]=!enable || (pad_held[p] && stage[p]>=2);
  assign groups[24+p]=!enable || (pad_held[p] && stage[p]>=3);
 end endgenerate
endmodule
