`timescale 1ns/1ps
// Controlled voice outputs isolate the production mixer, including signed extremes.
module pcm_pressure_note #(parameter PHASE_INC=0,DYNAMIC_PITCH=0,DUAL_WAVE=0)(
input clk,rst_n,sample_ce,pressure_valid,input[7:0]pressure_raw,input[31:0]runtime_inc,
output held,output reg signed[15:0]pcm=0,output reg pcm_valid=1,input sine_mode,output envelope_active);
assign held=0;assign envelope_active=0;
endmodule
module tb_shared64_mix;
reg clk=0;always #5 clk=~clk;reg rst=0,chord=1;reg signed[15:0]data[0:63];
pcm_pressure_poly32 #(.SHARED_ENGINE(0)) dut(.clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(64'd0),.voice_modes(16'd0),.chord_mode(chord),.test_mode(1'b0),.test32(1'b0),.test_mask(4'hf),.mask32(64'hffffffffffffffff));
genvar g;generate for(g=0;g<64;g=g+1)begin:inject
always @(negedge clk)dut.notes[g].legacy_state.note.pcm=data[g];end endgenerate
integer i,n,total,expected;reg[31:0]rng=32'h12345678;
task check;begin
@(negedge clk);@(posedge clk);#1;
total=0;for(i=0;i<64;i=i+1)total=total+$signed(data[i]);
expected=chord ? (total>>>5) : (total>>>2);
if(expected>32767)expected=32767;if(expected< -32768)expected=-32768;
if($signed(dut.mixed_pcm)!==expected)$fatal(1,"mixer n=%d got %d expected %d",n,$signed(dut.mixed_pcm),expected);
end endtask
initial begin for(i=0;i<64;i=i+1)data[i]=0;repeat(3)@(negedge clk);rst=1;
for(n=0;n<2000;n=n+1)begin
@(posedge clk);#1;chord=n<1000;
for(i=0;i<64;i=i+1)begin
rng=(rng<<1)^((rng[31])?32'h04c11db7:0);
if(n==0)data[i]=32767;else if(n==1)data[i]=-32768;else if(n==2)data[i]=(i%2)?32767:-32768;else data[i]=rng[15:0];
if(!chord && i>=8)data[i]=0;
end
check();end
$display("PASS 2000 production-mixer vectors: 64-way signed sum/32, basic sum/4, positive/negative saturation and no wrap");$finish;end
endmodule
