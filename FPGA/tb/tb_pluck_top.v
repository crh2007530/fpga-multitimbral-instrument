`timescale 1ns/1ps
module tb_pluck_top;
reg clk=0;always #10 clk=~clk;
reg ir=0;reg[1:0]cfg=2;reg[7:0]valid=255;reg[63:0]raw=0;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),
 .volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),
 .pluck_ir(ir),.bt_rx(1'b1),.ttp_sdo(1'b1));
// Only sensor timing and timeout are accelerated; audio engine is production RTL.
defparam dut.optical.FILTER_CYCLES=3,dut.optical.REARM_CYCLES=5;
defparam dut.pluck_observer.WAIT_CYCLES=5000;
task settle;begin repeat(2000)@(negedge clk);end endtask
task pluck;begin ir=0;settle;ir=1;settle;settle;settle;settle;end endtask
initial begin
force dut.pluck_config=cfg;force dut.audio_valid=valid;force dut.audio_raw=raw;
force dut.dashboard.frame_start=1;
wait(dut.audio_rst_n);settle;
if(dut.pluck_display[0]!==0)$fatal(1,"default disabled not visible");
cfg=3;settle;pluck;repeat(8)settle;
if(dut.pluck_result_audio!=2 || dut.pluck_display[23:8]!=1)$fatal(1,"empty pluck falsely triggered");
raw=64'h0000000000006060;settle;settle;
if(dut.audio_held32[7:0]!=0)$fatal(1,"pressure sounded without pluck");
pluck;
if(dut.audio_held32[1:0]!=3 || dut.pluck_result_audio!=3)$fatal(1,"actual two notes not reported gates=%h result=%d latched=%h gap=%d count=%h",dut.audio_held32[7:0],dut.pluck_result_audio,dut.pluck_route.latched,dut.pluck_route.gap,dut.pluck_display[23:8],"");
settle;if(dut.dashboard.pluck_data[6:5]!=3)$fatal(1,"result CDC display");
repeat(3)settle;if(dut.pluck_display[23:8]!=2)$fatal(1,"held obstruction repeated");
pluck;if(dut.pluck_display[23:8]!=3 || dut.pluck_result_audio!=3)$fatal(1,"second actual retrigger");
raw=0;settle;settle;if(dut.audio_held32[7:0]!=0)$fatal(1,"release failed");
force dut.trainer_active=1;settle;settle;
if(!dut.pluck_display[1] || dut.pluck_display[6:3]!=0 || dut.performance_config[1])$fatal(1,"game inhibition");
release dut.trainer_active;settle;
cfg=2;raw=64'h60;settle;settle;
if(!dut.audio_held32[0] || dut.pluck_display[0])$fatal(1,"normal pressure restore");
if(dut.underruns!=0)$fatal(1,"audio underrun");
$display("PASS production top optical-to-audio gates-to-HUD: empty pluck,two notes,held obstruction,retrigger,release,CDC,game inhibition,pressure restore,no underrun");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
always @(posedge dut.audio_clk) if(dut.audio_rst_n && dut.voice.ram_envelope_fault) $fatal(1,"envelope frame contract violated");
endmodule
