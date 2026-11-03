`timescale 1ns/1ps
module tb_effect_hud_top;
reg clk=0;always #10 clk=~clk;
pressure_poly8_top dut(.clk_50m(clk),.volume_a(1'b1),.volume_b(1'b1),.fx_button_n(1'b1),.game_button_n(1'b1),.encoder_a(1'b1),.encoder_b(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
reg[1:0]fx;reg[3:0]expr;integer i;
initial begin
wait(dut.rst_n);@(negedge clk);
force dut.extra_fx=fx;force dut.expression_config=expr;
force dut.game_raw=128'd0;force dut.test_mode=1'b0;
for(i=0;i<64;i=i+1)begin
fx=i[1:0];expr=i[5:2];#1;
if(dut.game_data[119:118]!==fx || dut.game_data[124:121]!==expr)$fatal(1,"top FX mapping");
end
$display("PASS top actual extra_fx/expression to unused HUD bits, all64 combinations");$finish;
end
endmodule
