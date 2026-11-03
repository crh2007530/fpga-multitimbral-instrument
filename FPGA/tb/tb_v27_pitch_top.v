`timescale 1ns/1ps
module tb_v27_pitch_top;
reg clk=0;always #10 clk=~clk;reg valid=0;reg[7:0]keys=0;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),.volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
task cmd;input[7:0]k;begin @(negedge clk);keys=k;valid=1;@(negedge clk);valid=0;repeat(160)@(negedge clk);end endtask
initial begin
force dut.bt_key_valid=valid;force dut.bt_key_mask=keys;force dut.dashboard.frame_start=1'b1;
wait(dut.audio_rst_n);repeat(160)@(negedge clk);
cmd(1);if(dut.dashboard.detail[111:96]!==16'h5555)$fatal(1,"low real control-to-CDC");
cmd(4);if(dut.dashboard.detail[111:96]!==16'haaaa)$fatal(1,"high real control-to-CDC");
cmd(2);if(dut.dashboard.detail[111:96]!==16'h0000)$fatal(1,"normal real control-to-CDC");
cmd(8);cmd(1);if(dut.dashboard.detail[115:112]!==4'd0 || dut.dashboard.detail[111:96]!==16'h0001)$fatal(1,"per-key real control-to-CDC");
force dut.trainer_active=1;repeat(160)@(negedge clk);if(dut.dashboard.detail[111:96]!==0)$fatal(1,"game applied pitch display");
$display("PASS real T1/T2/T3/T4 control path -> display pitch mailbox -> frame snapshot; game bypass matches audio");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
