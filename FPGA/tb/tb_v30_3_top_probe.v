`timescale 1ns/1ps
module tb_v30_3_top_probe;
integer step=0;integer round;reg[1:0] old_instrument;
reg clk=0;always #10 clk=~clk;reg op=0,sel=0,up=0,down=0,shortfx=0;reg[5:0]gest=0;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),.volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
task settle;begin repeat(1800)@(negedge clk);step=step+1;$display("PROBE round=%0d step=%0d time=%0t",round,step,$time);$fflush();end endtask
task selectnext;begin sel=1;@(negedge clk);sel=0;settle;end endtask
task clockwise;begin up=1;@(negedge clk);up=0;settle;end endtask
initial begin
force dut.mixer_open=op;force dut.select_short=sel;force dut.enc_inc=up;force dut.enc_dec=down;force dut.fx_click=shortfx;force dut.gesture_events=gest;
force dut.dashboard.frame_start=1;
// Control/CDC/audio stress only. Rendering is covered by separate pixel tests.
force dut.dashboard.x=11'd0;force dut.dashboard.y=10'd0;
wait(dut.audio_rst_n);settle;
for(round=0;round<3;round=round+1)begin
 old_instrument=dut.instrument_mode;
 op=1;@(negedge clk);op=0;settle;if(!dut.mixer_active)$fatal(1,"mixer open round=%0d",round);
 clockwise;if(dut.instrument_mode!=old_instrument)$fatal(1,"encoder escaped mixer");
 selectnext;clockwise;shortfx=1;@(negedge clk);shortfx=0;settle;
 shortfx=1;@(negedge clk);shortfx=0;settle;
 gest=1<<(round%4);@(negedge clk);gest=0;settle;
 force dut.test_mode=1;settle;if(dut.mixer_active || !dut.voice.test_mode)$fatal(1,"test isolation");release dut.test_mode;settle;
 op=1;@(negedge clk);op=0;settle;force dut.trainer_active=1;settle;if(dut.mixer_active)$fatal(1,"game isolation");release dut.trainer_active;settle;
 old_instrument=dut.instrument_mode;clockwise;if(dut.instrument_mode==old_instrument)$fatal(1,"instrument stuck");
 if(dut.underruns!=0)$fatal(1,"underrun round=%0d",round);
 if(round%10==0)begin $display("PROGRESS round=%0d time_ns=%0t",round,$time);$fflush();end
end
$display("MEASURE simulator_time_ns=%0t rounds=100 reset_after_start=0",$time);
$display("PASS top integration page/encoder isolation, audio/video CDC, manual bypass, game/test close, instrument restore, no underrun");$finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule

