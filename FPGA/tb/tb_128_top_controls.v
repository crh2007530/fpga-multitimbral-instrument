`timescale 1ns/1ps
module tb_128_top_controls;
reg clk=0;always #10 clk=~clk;
reg rv=0;reg[7:0]rk=0;reg[127:0]expected=~128'd0;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),.volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
task command;input[7:0]k;begin @(negedge clk);rv=1;rk=k;@(negedge clk);rv=0;repeat(8)@(negedge clk);end endtask
task check;input integer n;begin
 repeat(4000)@(negedge clk);
 if(dut.voice.mask32!==expected)$fatal(1,"128-bit CDC mismatch selected %0d",n);
 if(dut.audio_held128!==expected)$fatal(1,"real gate mismatch selected %0d",n);
 if(dut.underruns!=0)$fatal(1,"I2S underrun");
 if(dut.dashboard.snapshot[184]!==dut.selected_test[6])$fatal(1,"display bank");
 if(dut.dashboard.snapshot[254:191]!==(dut.selected_test[6]?expected[127:64]:expected[63:0]))$fatal(1,"display mask");
end endtask
initial begin
 force dut.bt_key_valid=rv;force dut.bt_key_mask=rk;
 force dut.dashboard.frame_start=1;force dut.dashboard.x=0;force dut.dashboard.y=0;
 wait(dut.audio_rst_n);repeat(200)@(negedge clk);
 command(32);command(16);check(0);
 command(32);expected[0]=0;check(0);
 command(2);command(32);expected[64]=0;check(64);
 command(4);command(32);expected[63]=0;check(63);
 command(1);command(4);command(32);expected[127]=0;check(127);
 command(64);expected=~128'd0;check(127);
 command(128);repeat(4000)@(negedge clk);
 if(dut.voice.test_mode || dut.test_mode)$fatal(1,"exit");
 $display("PASS actual top control-to-CDC-to-128-voice gates and paged display: independently mute 1,64,65,128; restore; exit; no I2S underrun");$finish;
end
initial begin #50000000;$fatal(1,"timeout");end
always @(posedge dut.audio_clk) if(dut.audio_rst_n && dut.voice.ram_envelope_fault) $fatal(1,"envelope frame contract violated");
endmodule
