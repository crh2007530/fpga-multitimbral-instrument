`timescale 1ns/1ps
module tb_v25_1_cleanup;
reg clk=0;always #10 clk=~clk;
wire os,od;reg[5:0]id=0;wire[9:0]reference_bin;integer i;
test64_bin reference_map(id,reference_bin);
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),.volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1),.oled_scl(os),.oled_sda(od));
always @(negedge clk) if(os!==1'bz || od!==1'bz)$fatal(1,"former OLED pins must stay released");
initial begin
wait(dut.rst_n);repeat(500)@(negedge clk);
force dut.dashboard.test_voice=id;force dut.dashboard.test64=1;
for(i=0;i<64;i=i+1)begin id=i;#1;
 if(dut.dashboard.measured_tone_bin!==reference_bin || dut.dashboard.fft_read_bin!==reference_bin)$fatal(1,"changed diagnostic frequency address %d",i);
end
id=6'bxxxxxx;#1;if(dut.dashboard.measured_tone_bin!==10'd0)$fatal(1,"unknown default changed");
force dut.dashboard.test64=0;force dut.dashboard.spectrum_x=11'd997;#1;
if(dut.dashboard.fft_read_bin!==10'd997)$fatal(1,"normal FFT addressing changed");
release dut.dashboard.test64;release dut.dashboard.test_voice;release dut.dashboard.spectrum_x;
force dut.count=21'd1999999;#1;if(dut.tick!==1'b1)$fatal(1,"telemetry cadence changed");release dut.count;
repeat(2)@(negedge clk);
if(dut.sequence_id!==16'd1)$fatal(1,"telemetry stalled without OLED");
$display("PASS OLED pins always high-Z; all64 FFT addresses exactly preserved incl default; normal spectrum and UART cadence retained");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
