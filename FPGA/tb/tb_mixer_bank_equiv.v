`timescale 1ns/1ps
`include "tb/v50_mixer_reference.v"
module tb_mixer_bank_equiv;
reg clk=0;always #5 clk=~clk;
reg rst_n=0;reg[13:0] controls=0;reg[2:0]base_enable=0;reg[1:0]instrument=0;
wire[48:0] ref_out,dut_out;
ref_instrument_mixer_controls ref_dut(.clk(clk),.rst_n(rst_n),.blocked(controls[0]),.open_event(controls[1]),.next_event(controls[2]),.prev_event(controls[3]),.inc(controls[4]),.dec(controls[5]),.base_enable(base_enable),.remote_write(controls[6]),.echo_event(controls[7]),.echo_clear(controls[8]),.instrument(instrument),.active(ref_out[0]),.item(ref_out[4:1]),.config_data(ref_out[37:5]),.effective_enable(ref_out[40:38]),.echo_preset(ref_out[42:41]),.chorus_preset(ref_out[44:43]),.edited(ref_out[47:45]),.current_instrument());
instrument_mixer_controls dut(.clk(clk),.rst_n(rst_n),.blocked(controls[0]),.open_event(controls[1]),.next_event(controls[2]),.prev_event(controls[3]),.inc(controls[4]),.dec(controls[5]),.base_enable(base_enable),.remote_write(controls[6]),.echo_event(controls[7]),.echo_clear(controls[8]),.instrument(instrument),.active(dut_out[0]),.item(dut_out[4:1]),.config_data(dut_out[37:5]),.effective_enable(dut_out[40:38]),.echo_preset(dut_out[42:41]),.chorus_preset(dut_out[44:43]),.edited(dut_out[47:45]),.current_instrument());
assign ref_out[48]=0;assign dut_out[48]=0;
integer i;reg[31:0] rng=32'h81002026;
initial begin
repeat(3)@(negedge clk);
for(i=0;i<100000;i=i+1)begin
 if(dut_out!==ref_out || dut.current_instrument!==ref_dut.current_instrument)$fatal(1,"cache mismatch cycle %0d",i);
 if(^dut_out===1'bx)$fatal(1,"invalid cache exposed unknown data");
 rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
 rst_n=(i%997)!=0;controls=rng[13:0];base_enable=rng[16:14];instrument=rng[18:17];
 @(negedge clk);
end
$display("PASS mixer valid-cache exact four-state equivalence: 100000 randomized cycles, repeated reset, all instrument selections and control collisions; no unknown output");$finish;
end
endmodule
