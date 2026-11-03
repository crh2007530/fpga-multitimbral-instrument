`timescale 1ns/1ps
// Read-only observer: no signal from this module controls the sound engine.
// A rising base-voice gate is evidence of an accepted note, not DAC audibility.
module pluck_note_observer #(parameter integer WAIT_CYCLES=246000)(
 input clk,rst_n,enable,event_toggle,input[7:0] gates,output reg[1:0] result);
 reg enabled_q,seen;reg[7:0] previous;
 reg[$clog2(WAIT_CYCLES+1)-1:0] age;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin enabled_q<=0;seen<=0;previous<=0;age<=0;result<=0;end
 else begin
  enabled_q<=enable;previous<=gates;
  if(!enable || !enabled_q)begin seen<=event_toggle;age<=0;result<=0;end
  else if(seen!=event_toggle)begin seen<=event_toggle;age<=0;result<=1;end
  else if(result==1)begin
   if(|(gates & ~previous))begin result<=3;age<=0;end
   else if(age==WAIT_CYCLES-1)begin result<=2;age<=0;end
   else age<=age+1'b1;
  end
 end
endmodule

// BCD display count saturates at9999 and clears only at reset.
// Feedback pulse is extended for200ms so a human can see a single pluck.
module pluck_status #(parameter integer HOLD_CYCLES=10000000)(
 input clk,rst_n,configured,inhibited,blocked,armed,event_pulse,
 input[1:0] note_result,output wire[23:0] data);
 reg[15:0] count_bcd;reg[$clog2(HOLD_CYCLES+1)-1:0] hold_age;
 wire enabled=configured && !inhibited;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin count_bcd<=0;hold_age<=0;end
 else begin
  if(!enabled)hold_age<=0;
  else if(event_pulse)hold_age<=HOLD_CYCLES;
  else if(hold_age!=0)hold_age<=hold_age-1'b1;
  if(enabled && event_pulse && count_bcd!=16'h9999)begin
   if(count_bcd[3:0]!=9)count_bcd[3:0]<=count_bcd[3:0]+1'b1;
   else begin count_bcd[3:0]<=0;
    if(count_bcd[7:4]!=9)count_bcd[7:4]<=count_bcd[7:4]+1'b1;
    else begin count_bcd[7:4]<=0;
     if(count_bcd[11:8]!=9)count_bcd[11:8]<=count_bcd[11:8]+1'b1;
     else begin count_bcd[11:8]<=0;count_bcd[15:12]<=count_bcd[15:12]+1'b1;end
    end
   end
  end
 end
 assign data={count_bcd,1'b0,enabled?note_result:2'd0,
   enabled && hold_age!=0,enabled && armed,blocked,inhibited,configured};
endmodule
