`timescale 1ns/1ps
module tb_v30_practice;
reg clk=0;always #10 clk=~clk;
reg sh=0,lo=0,rv=0;reg[7:0]rk=0;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),.volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
task settle;begin repeat(2000)@(negedge clk);end endtask
task exit_mode;begin rv=1;rk=128;@(negedge clk);rv=0;rk=0;settle;end endtask
initial begin
force dut.select_short=sh;force dut.select_long=lo;force dut.bt_key_valid=rv;force dut.bt_key_mask=rk;
force dut.dashboard.frame_start=1;
wait(dut.audio_rst_n);settle;
lo=1;@(negedge clk);lo=0;settle;
if(!dut.trainer_active || !dut.practice_mode || dut.trainer_running || dut.game_data[30] || !dut.game_data[100])$fatal(1,"practice entry HUD");
wait(dut.joint_lights.state==0);repeat(4)@(negedge clk);
if(dut.joint_lights.led_data[0]!==24'h000040 || dut.joint_lights.led_data[3]!==0)$fatal(1,"practice target not regional");
sh=1;@(negedge clk);sh=0;settle;
if(!dut.trainer_running || dut.game_data[30])$fatal(1,"practice start");
exit_mode;
if(dut.practice_mode || dut.game_data[100] || dut.trainer_active)$fatal(1,"practice exit");
sh=1;@(negedge clk);sh=0;settle;
if(!dut.trainer_active || dut.practice_mode || !dut.game_data[30] || !dut.trainer_running)$fatal(1,"short game entry");
exit_mode;
if(dut.game_data[100])$fatal(1,"game exit falsely shows practice");
$display("PASS white-page practice entry/start/exit, regional target light, short game entry, HUD separation");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
always @(posedge dut.audio_clk) if(dut.audio_rst_n && dut.voice.ram_envelope_fault) $fatal(1,"envelope frame contract violated");
endmodule
