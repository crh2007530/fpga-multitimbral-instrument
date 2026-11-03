`timescale 1ns/1ps
// 0 PLUCK, 1 FLUTE, 2 E.PIANO. Physical rotation wins a simultaneous remote event.
module instrument_select(input wire clk,rst_n,clear,test_mode,next_event,inc,dec,
 output reg[1:0] mode);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)mode<=0;
 else if(clear)mode<=0;
 else if(!test_mode)begin
  if(inc && !dec)mode<=mode==2?2'd0:mode+2'd1;
  else if(dec && !inc)mode<=mode==0?2'd2:mode-2'd1;
  else if(!inc && !dec && next_event)mode<=mode==2?2'd0:mode+2'd1;
 end
endmodule
