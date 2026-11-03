`timescale 1ns/1ps
// Independent control, phase and envelope state. Arithmetic/ROM may be shared.
module pressure_voice_state_v18_reference #(parameter integer AUDIO_HZ=24600000, ON_RAW=20, OFF_RAW=10, DEFER_PHASE=0, INSTRUMENTS=0,THIRD_TIMBRE=0)(
 input wire clk,rst_n,sample_ce,pressure_valid,
 input wire phase_ce,
 input wire flute_mode,test_mode,
 input wire [7:0] pressure_raw,input wire [31:0] phase_inc,
 output reg held,output wire envelope_active,
 output reg [9:0] address,output reg [15:0] force_snapshot,envelope_snapshot,input wire epiano_mode,output reg[15:0] increment_snapshot);
 localparam integer STALE_CYCLES=AUDIO_HZ/100;
 reg note_on,note_off,last_test;
 reg [15:0] force_hold;
 localparam integer AGE_W=$clog2(STALE_CYCLES+1);
 reg [AGE_W-1:0] age;reg [31:0] phase;
 wire [15:0] envelope;
 reg ce_d1,ce_d2;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   held<=0;note_on<=0;note_off<=0;last_test<=0;force_hold<=0;age<=STALE_CYCLES;
  end else begin
   note_on<=0;note_off<=0;last_test<=test_mode;
   if(INSTRUMENTS && test_mode!=last_test)begin held<=0;note_off<=1;age<=0;end
   else if(pressure_valid) begin
    age<=0;
    if(!held && pressure_raw>=ON_RAW)begin held<=1;note_on<=1;end
    else if(held && pressure_raw<=OFF_RAW)begin held<=0;note_off<=1;end
    if(pressure_raw>OFF_RAW)force_hold<={1'b0,pressure_raw,7'b0};
   end else begin
    if(age<STALE_CYCLES)age<=age+1'b1;
    if(age>=STALE_CYCLES && held)begin held<=0;note_off<=1;end
   end
  end
 end
 generate if(INSTRUMENTS)begin: presets
 instrument_env #(.THIRD_TIMBRE(THIRD_TIMBRE)) env(.epiano(epiano_mode),.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),.note_on(note_on),.note_off(note_off),.flute(flute_mode),.diagnostic(test_mode),.level(envelope),.active(envelope_active));
 end else begin: original
 adsr_env env(.clk(clk),.rst_n(rst_n),.sample_ce(sample_ce),.note_on(note_on),.note_off(note_off),.level(envelope),.active(envelope_active),.state());
 end endgenerate
 // Preserve legacy sample semantics: DDS address at request; gain operands
 // two cycles later. This includes pressure updates near the request edge.
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin phase<=0;address<=0;increment_snapshot<=0;ce_d1<=0;ce_d2<=0;force_snapshot<=0;envelope_snapshot<=0;end
  else begin
   ce_d1<=sample_ce;ce_d2<=ce_d1;
   if(sample_ce)address<=phase[31:22];
   if(INSTRUMENTS && !test_mode && note_on)phase<=0;
   else if(DEFER_PHASE ? phase_ce : sample_ce)begin phase<=phase+phase_inc;increment_snapshot<=phase_inc[31:16];end
   if(ce_d2)begin force_snapshot<=force_hold;envelope_snapshot<=envelope;end
  end
 end
endmodule
