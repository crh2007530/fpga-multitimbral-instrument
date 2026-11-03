`timescale 1ns/1ps
module tb_v28_top;
reg clk=0;always #10 clk=~clk;reg op=0,sel=0,up=0,down=0,shortfx=0;reg[5:0]gest=0;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),.volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
task settle;begin repeat(1800)@(negedge clk);end endtask
task selectnext;begin sel=1;@(negedge clk);sel=0;settle;end endtask
task clockwise;begin up=1;@(negedge clk);up=0;settle;end endtask
initial begin
force dut.mixer_open=op;force dut.select_short=sel;force dut.enc_inc=up;force dut.enc_dec=down;force dut.fx_click=shortfx;force dut.gesture_events=gest;
force dut.dashboard.frame_start=1;
wait(dut.audio_rst_n);settle;
op=1;@(negedge clk);op=0;settle;if(!dut.mixer_active)$fatal(1,"page not open");
clockwise;if(dut.instrument_mode!=0 || dut.mixer_enable!=1)$fatal(1,"encoder crossed into instrument");
selectnext;clockwise;if(dut.voice.send_config[13:12]!=1 || !dut.voice.extra_fx[0])$fatal(1,"audio CDC config lost");
if(!dut.dashboard.mixer_data[33] || dut.dashboard.mixer_data[37:34]!=1)$fatal(1,"display CDC lost");
shortfx=1;@(negedge clk);shortfx=0;settle;if(!dut.voice.send_bypass)$fatal(1,"manual bypass path");
shortfx=1;@(negedge clk);shortfx=0;settle;
// Later gesture echo event should own enable state, while retaining the preset values.
gest=2;@(negedge clk);gest=0;settle;
force dut.test_mode=1;settle;if(dut.mixer_active || !dut.voice.test_mode)$fatal(1,"test isolation");release dut.test_mode;settle;
op=1;@(negedge clk);op=0;settle;force dut.trainer_active=1;settle;if(dut.mixer_active)$fatal(1,"game isolation");release dut.trainer_active;settle;
clockwise;if(dut.instrument_mode==0)$fatal(1,"instrument encoder outside mixer lost");
if(dut.underruns!=0)$fatal(1,"top underrun");
$display("PASS top integration page/encoder isolation, audio/video CDC, manual bypass, game/test close, instrument restore, no underrun");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
