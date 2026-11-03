`timescale 1ns/1ps
// Latest-value queue per pad. Commit once per I2S frame, eight clocks before
// sample_ce. Simultaneous arrival wins; no input is lost on the commit edge.
// Arrival-to-admission is 0..511 clocks, NOT zero asynchronous input jitter.
module frame_pressure(input wire clk,rst_n,control_ce,
 input wire [7:0] input_valid,input wire [63:0] input_raw,
 output wire [7:0] output_valid,output wire [63:0] output_raw);
 reg [63:0] latest;
 reg [7:0] pending;
 genvar n;
 generate for(n=0;n<8;n=n+1)begin:pad
   assign output_raw[8*n+:8]=input_valid[n] ? input_raw[8*n+:8] : latest[8*n+:8];
   assign output_valid[n]=control_ce && (pending[n] || input_valid[n]);
   always @(posedge clk or negedge rst_n)
     if(!rst_n)begin latest[8*n+:8]<=0;pending[n]<=0;end
     else begin
       if(input_valid[n])latest[8*n+:8]<=input_raw[8*n+:8];
       if(control_ce)pending[n]<=0;
       else if(input_valid[n])pending[n]<=1;
     end
 end endgenerate
endmodule

// Live post-effect PCM: retain one sample in eight, 64 points (~10.66 ms).
// Fixed gain 1 screen pixel / 128 PCM counts, saturate at +/-15 pixels.
// The OLED takes an atomic snapshot; display traffic cannot stall audio.
module audio_waveform(input wire clk,rst_n,sample_valid,
 input wire signed [15:0] sample_pcm,output reg [319:0] points);
 reg [2:0] decimate;
 wire signed [15:0] scaled=sample_pcm>>>7;
 // Within -15..15 the modulo-32 subtraction is exactly the screen coordinate.
 wire [4:0] y=scaled>15 ? 5'd1 : scaled< -15 ? 5'd31 : 5'd16-scaled[4:0];
 always @(posedge clk or negedge rst_n)
   if(!rst_n)begin decimate<=0;points<={64{5'd16}};end
   else if(sample_valid)begin
     decimate<=decimate+1'b1;
     if(decimate==7)points<={y,points[319:5]};
   end
endmodule
