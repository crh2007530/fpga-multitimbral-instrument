`timescale 1ns/1ps
// Qualified optical interruption. Startup/enable requires a clear slot first.
// Neither a held obstruction nor power-up with an obstructed slot emits notes.
module optical_pluck #(parameter integer FILTER_CYCLES=5000,REARM_CYCLES=100000)(
 input clk,rst_n,enable,blocked_high,raw,
 output reg event_pulse,output reg blocked,output reg armed,output reg[15:0] count);
 reg[1:0] sync;
 reg[$clog2(FILTER_CYCLES+1)-1:0] filter;
 reg[$clog2(REARM_CYCLES+1)-1:0] clear_age;
 wire sensed=blocked_high?sync[1]:!sync[1];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin sync<=3;filter<=0;clear_age<=0;blocked<=1;armed<=0;event_pulse<=0;count<=0;end
 else begin
  sync<={sync[0],raw};event_pulse<=0;
  if(sensed==blocked)filter<=0;
  else if(filter==FILTER_CYCLES-1)begin blocked<=sensed;filter<=0;end
  else filter<=filter+1'b1;
  if(!enable)begin armed<=0;clear_age<=0;end
  else if(blocked)begin
   clear_age<=0;
   if(armed)begin event_pulse<=1;count<=count+1'b1;armed<=0;end
  end else if(!armed)begin
   if(clear_age==REARM_CYCLES-1)begin armed<=1;clear_age<=0;end
   else clear_age<=clear_age+1'b1;
  end
 end
endmodule

// An atomic pluck toggle is received in the audio clock domain. Two silent
// control frames force note re-trigger, then selected pressure pads sound.
module pluck_pressure(input clk,rst_n,control_ce,enable,event_toggle,
 input[7:0] input_valid,input[63:0] input_raw,
 output wire[7:0] output_valid,output wire[63:0] output_raw);
 reg[63:0] latest,latched;reg seen,previous_enable;reg[1:0] gap;
 integer i;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin latest<=0;latched<=0;seen<=0;gap<=0;previous_enable<=0;end
 else begin
  for(i=0;i<8;i=i+1)if(input_valid[i])latest[i*8+:8]<=input_raw[i*8+:8];
  if(control_ce)begin
   previous_enable<=enable;
   if(!enable || !previous_enable)begin seen<=event_toggle;latched<=0;gap<=0;end
   else if(event_toggle!=seen)begin seen<=event_toggle;latched<=latest;gap<=2;end
   else if(gap!=0)gap<=gap-1'b1;
   else for(i=0;i<8;i=i+1)if(latest[i*8+:8]<=10)latched[i*8+:8]<=0;
  end
 end
 // Never manufacture endless fresh pressure samples: if an ADC disconnects,
 // the existing 10ms voice watchdog must still release its notes.
 assign output_valid=enable?(input_valid | {8{control_ce && gap!=0}}):input_valid;
 assign output_raw=enable?(gap!=0?64'd0:latched):input_raw;
endmodule
