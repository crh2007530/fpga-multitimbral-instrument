`timescale 1ns/1ps
// User-controlled Q1.15 linear ADSR, step sizes computed by the control app.
// Each instance retains independent gate/envelope state.
module adjustable_adsr(input clk,rst_n,ce,gate,enable,
 input[14:0] attack_step,decay_step,sustain_level,release_step,
 output reg[15:0] level,output wire active);
 localparam IDLE=0,A=1,D=2,S=3,R=4;
 reg[2:0]state;reg last_gate;
 wire[15:0] a={1'b0,attack_step},d={1'b0,decay_step},r={1'b0,release_step};
 wire[15:0] s={1'b0,sustain_level};
 assign active=state!=IDLE;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin level<=0;state<=IDLE;last_gate<=0;end
 else if(ce)begin
  last_gate<=gate;
  if(!enable)begin level<=0;state<=IDLE;last_gate<=0;end
  else if(gate && !last_gate)begin level<=0;state<=A;end
  else if(!gate && last_gate)state<=R;
  else case(state)
   IDLE:level<=0;
   A:if(level>=16'd32767-a)begin level<=32767;state<=D;end else level<=level+a;
   D:if(level<=s || level-s<=d)begin level<=s;state<=S;end else level<=level-d;
   S:level<=s;
   R:if(level<=r)begin level<=0;state<=IDLE;end else level<=level-r;
   default:begin level<=0;state<=IDLE;end
  endcase
 end
endmodule
