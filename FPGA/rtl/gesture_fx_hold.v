`timescale 1ns/1ps
// Proximity is a temporary override, never writes the user's effect settings.
module gesture_fx_hold(input clk,rst_n,test_mode,locked,input[5:0] events,output reg bypass);
always @(posedge clk or negedge rst_n)
 if(!rst_n)bypass<=0;
 else if(test_mode)bypass<=0;
 // Far can always release an existing hold, even if remote controls are locked.
 else if(events[5])bypass<=0;
 else if(!locked && events[4])bypass<=1;
endmodule
