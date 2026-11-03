`timescale 1ns/1ps
module tb_v50_gesture;
reg[1:0] saved_instrument_fx;
reg clk=0;always #10 clk=~clk;reg[5:0]ev=0;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),.volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
task event_;input[5:0]e;begin ev=e;ticks(1);ev=0;ticks(1600);end endtask
initial begin
force dut.gesture_events=ev;wait(dut.audio_rst_n);ticks(1600);
force dut.extra_fx=2'b11;
event_(1);if(dut.instrument_mode!=1)$fatal(1,"up instrument");
event_(1);if(dut.instrument_mode!=2)$fatal(1,"up piano");
event_(2);if(!dut.expression_config[3])$fatal(1,"down echo");
event_(4);if(!dut.expression_config[1])$fatal(1,"left glide");
event_(8);if(!dut.expression_config[2])$fatal(1,"right vibrato");
saved_instrument_fx=dut.voice.extra_fx;
if(saved_instrument_fx!=0)$fatal(1,"piano inherited harmonica effect switches");
event_(16);if(!dut.fx_bypass || dut.voice.extra_fx!=0 || dut.voice.expression_config[3])$fatal(1,"near dry");
if(dut.game_data[118] || dut.game_data[119] || dut.game_data[124] || !dut.game_data[117])$fatal(1,"near HUD");
if(!dut.voice.expression_config[1] || !dut.voice.expression_config[2])$fatal(1,"near removed expression");
event_(32);if(dut.fx_bypass || dut.voice.extra_fx!=saved_instrument_fx || !dut.voice.expression_config[3])$fatal(1,"far restore");
force dut.manual_fx_bypass=1;event_(16);event_(32);if(!dut.fx_bypass)$fatal(1,"far undid button");release dut.manual_fx_bypass;
force dut.bt_control_lock=1;event_(16);if(dut.gesture_fx_bypass)$fatal(1,"remote lock");release dut.bt_control_lock;
event_(16);force dut.bt_control_lock=1;event_(32);if(dut.gesture_fx_bypass)$fatal(1,"locked far release");release dut.bt_control_lock;
force dut.test_mode=1;event_(16);if(dut.gesture_fx_bypass)$fatal(1,"test isolation");release dut.test_mode;
$display("PASS six gestures to production audio/HUD, original effect settings preserved, physical bypass priority, lock release and test isolation");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
