`timescale 1ns/1ps
// A second quadrature encoder controls attenuation only. Separate NO button.
// A qualified release is required at boot and after each accepted press.
module panel_controls #(parameter FILTER_CYCLES=50000,BUTTON_CYCLES=500000)(
 input clk,rst_n,a,b,key_n,output reg[4:0] volume,output reg[6:0] percent,output reg click);
 wire up,down;
 encoder_input #(.FILTER_CYCLES(FILTER_CYCLES)) rotary(
 .clk(clk),.rst_n(rst_n),.a(a),.b(b),.key_n(1'b1),.inc(up),.dec(down),.click());
 localparam CW=BUTTON_CYCLES<2?1:$clog2(BUTTON_CYCLES);
 reg meta,sync,candidate,armed;
 reg[CW-1:0] count;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin volume<=16;meta<=1;sync<=1;candidate<=1;armed<=0;count<=0;click<=0;end
 else begin
  meta<=key_n;sync<=meta;click<=0;
  if(up && !down && volume<16)volume<=volume+1'b1;
  else if(down && !up && volume>0)volume<=volume-1'b1;
  if(sync!=candidate)begin candidate<=sync;count<=0;end
  else if(count==BUTTON_CYCLES-1)begin
   if(candidate)armed<=1;
   else if(armed)begin click<=1;armed<=0;end
  end else count<=count+1'b1;
 end
 always @*case(volume)
 0:percent=0;1:percent=6;2:percent=13;3:percent=19;
 4:percent=25;5:percent=31;6:percent=38;7:percent=44;
 8:percent=50;9:percent=56;10:percent=63;11:percent=69;
 12:percent=75;13:percent=81;14:percent=88;15:percent=94;
 default:percent=100;
 endcase
endmodule

// Standalone pushbutton: no encoder or unused volume datapath is instantiated.
module momentary_button #(parameter BUTTON_CYCLES=500000)(
 input clk,rst_n,key_n,output reg click);
 localparam CW=BUTTON_CYCLES<2?1:$clog2(BUTTON_CYCLES);
 reg meta,sync,candidate,armed;
 reg[CW-1:0] count;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin meta<=1;sync<=1;candidate<=1;armed<=0;count<=0;click<=0;end
 else begin
  meta<=key_n;sync<=meta;click<=0;
  if(sync!=candidate)begin candidate<=sync;count<=0;end
  else if(count==BUTTON_CYCLES-1)begin
   if(candidate)armed<=1;
   else if(armed)begin click<=1;armed<=0;end
  end else count<=count+1'b1;
 end
endmodule
