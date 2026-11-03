`timescale 1ns/1ps
// Config bits: 0 flute, 1 portamento, 2 vibrato, 3 echo.
// APDS directions: up/down/left/right = bits 0/1/2/3.
module expression_controls(input wire clk,rst_n,clear,test_mode,
 input wire [5:0] events, output reg [3:0] config_bits);
 always @(posedge clk or negedge rst_n)
 if(!rst_n) config_bits<=0;
 else if(clear) config_bits<=0;
 else if(!test_mode) begin
   if(events[0])config_bits[0]<=~config_bits[0];
   if(events[2])config_bits[1]<=~config_bits[1];
   if(events[3])config_bits[2]<=~config_bits[2];
   if(events[1])config_bits[3]<=~config_bits[3];
 end
endmodule

// Shared ~5Hz triangle LFO, -8..+8, sampled only at the audio frame rate.
module expression_lfo(input wire clk,rst_n,sample_ce,
 output reg signed [4:0] level);
 reg [8:0] divider; reg down;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin divider<=0;level<=0;down<=0;end
 else if(sample_ce)begin
   if(divider==299)begin
     divider<=0;
     if(!down)begin
       if(level==7)begin level<=8;down<=1;end
       else level<=level+1'b1;
     end else begin
       if(level== -7)begin level<= -8;down<=0;end
       else level<=level-1'b1;
     end
   end else divider<=divider+1'b1;
 end
endmodule

module expression_pitch(input wire clk,rst_n,sample_ce,glide,vibrato,
 input wire [31:0] target, input wire signed [4:0] lfo,
 output wire [31:0] phase_inc);
 reg [31:0] current;reg initialized;
 wire [31:0] distance=(target>=current)?target-current:current-target;
 wire [31:0] step_size=(distance>>9);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin current<=0;initialized<=0;end
 else if(sample_ce)begin
   initialized<=1;
   if(!glide || !initialized || distance<512)current<=target;
   else if(target>current)current<=current+step_size;
   else current<=current-step_size;
 end
 wire [31:0] base=(glide && initialized)?current:target;
 // +/-0.78125%, approximately +/-13.5 cents. Fixed-width shift/add
 // avoids adding 32 DSP multipliers to the existing 32-voice engine.
 // LFO contract is -8..+8; magnitude always fits four bits.
 wire [3:0] magnitude=lfo[4] ? 4'd0-lfo[3:0] : lfo[3:0];
 wire [31:0] unit_step=base>>10;
 wire [31:0] delta=(magnitude[0]?unit_step:32'd0)+
   (magnitude[1]?(unit_step<<1):32'd0)+
   (magnitude[2]?(unit_step<<2):32'd0)+
   (magnitude[3]?(unit_step<<3):32'd0);
 assign phase_inc=!vibrato?base:(lfo[4]?base-delta:base+delta);
endmodule
