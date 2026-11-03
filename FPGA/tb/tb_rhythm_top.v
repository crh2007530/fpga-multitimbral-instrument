`timescale 1ns/1ps
module tb_rhythm_top;
reg clk=0;always #10 clk=~clk;tri1 a,b,c,d,e,f;reg rx=1;wire tx;
pressure_poly8_top #(.BT_CLOCK_HZ(320000),.BT_BAUD(10000),.TRAINER_CLOCK_HZ(240000)) dut(
 .volume_a(1'b1),.volume_b(1'b1),.fx_button_n(1'b1),.game_button_n(1'b1),.encoder_a(1'b1),.encoder_b(1'b1),.clk_50m(clk),.bt_rx(rx),.bt_tx(tx),.adc0_scl(a),.adc0_sda(b),.adc1_scl(c),.adc1_sda(d),.apds_sda(e),.oled_sda(f),.ttp_sdo(1'b1));
reg[7:0]keys=0;reg fv=0;reg[5:0]ge=0;
initial begin force dut.touch_keys=keys;force dut.touch_valid=fv;force dut.gesture_events=ge;force dut.audio_raw=0;force dut.audio_valid=255;end
task byte_send;input[7:0]v;integer j;begin
 @(negedge clk);rx=0;repeat(32)@(negedge clk);
 for(j=0;j<8;j=j+1)begin rx=v[j];repeat(32)@(negedge clk);end
 rx=1;repeat(32)@(negedge clk);
end endtask
// Kept explicit so both command and CDC/audio-frame settling are exercised.
task send_cmd;input[7:0]v;begin byte_send("@");byte_send(v);byte_send(10);repeat(2000)@(negedge clk);end endtask
task frame;input[7:0]k;begin @(negedge clk);keys=k;fv=1;repeat(4)@(negedge clk);fv=0;repeat(3)@(negedge clk);end endtask
initial begin
 wait(dut.audio_rst_n);repeat(2000)@(negedge clk);
 force dut.enc_inc=1'b1;@(negedge clk);release dut.enc_inc;repeat(2000)@(negedge clk);
 if(!dut.expression_config[0] || !dut.audio_config[87])$fatal(1,"encoder selects flute");
 force dut.enc_dec=1'b1;@(negedge clk);release dut.enc_dec;repeat(2000)@(negedge clk);
 if(dut.expression_config[0] || dut.audio_config[87])$fatal(1,"encoder selects pluck");
 send_cmd("1");if(dut.voice_modes!=16'h5555 || dut.audio_config[15:0]!=16'h5555)$fatal(1,"remote octave CDC");
 send_cmd("3");if(dut.voice_modes!=16'haaaa)$fatal(1,"remote high");
 send_cmd("6");if(!dut.chord_mode || !dut.audio_config[21])$fatal(1,"remote chord");
 send_cmd("A");send_cmd("B");send_cmd("C");send_cmd("D");
 if(dut.expression_config!=15 || dut.audio_config[90:87]!=15)$fatal(1,"remote effects CDC");
 send_cmd("W");if(dut.visual_mode!=0 || dut.visual_auto)$fatal(1,"wave");
 send_cmd("S");if(dut.visual_mode!=1)$fatal(1,"spectrum");send_cmd("X");if(dut.visual_mode!=2)$fatal(1,"XY");
 send_cmd("R");if(!dut.visual_auto)$fatal(1,"rotation");
 send_cmd("5");if(!dut.test_mode || !dut.test32)$fatal(1,"FFT64");
 if(!dut.game_data[127] || !dut.game_data[126])$fatal(1,"diagnostic banner missing");
 send_cmd("4");send_cmd("6");if(dut.mask32!==64'hfffffffffffffffd || dut.audio_config[86:23]!==64'hfffffffffffffffd)$fatal(1,"remote64 mask CDC");
 send_cmd("T");if(dut.trainer_active)$fatal(1,"FFT trainer blocked");
 send_cmd("8");if(dut.test_mode||dut.expression_config||dut.chord_mode)$fatal(1,"safe reset");
 if(dut.game_data[127])$fatal(1,"diagnostic banner stuck");
 send_cmd("T");if(!dut.trainer_active || dut.audio_config!=0)$fatal(1,"trainer entry");
 send_cmd("2");send_cmd("3");send_cmd("4");
 if(dut.trainer_song!=0 || dut.trainer_tempo!=2 || dut.trainer_wait)$fatal(1,"fixed practice settings");
 send_cmd("A");if(dut.expression_config[0]!=1 || dut.audio_config[87]!=1 || !dut.game_data[101])$fatal(1,"game timbre CDC/HUD");
 if(dut.logger.expression_config!==dut.expression_config)$fatal(1,"game effects telemetry inconsistent");
 force dut.trainer.correct_held=8'h80;#1;
 if(dut.joint_lights.guide_target!== (dut.trainer_target | 8'h80))$fatal(1,"LED success feedback disconnected");
 release dut.trainer.correct_held;
 send_cmd("5");if(!dut.trainer_running || dut.test_mode || dut.trainer_count!=4)$fatal(1,"lesson start");
 send_cmd("2");if(dut.trainer_song!=0)$fatal(1,"running song guard");
 send_cmd("5");if(dut.trainer_running)$fatal(1,"pause");
 send_cmd("6");if(dut.trainer_count || dut.trainer_step || dut.trainer_running)$fatal(1,"restart");
 send_cmd("8");if(dut.trainer_active || dut.selected!=8)$fatal(1,"lesson exit");
 // Local touch remains usable after Bluetooth; repeated remote keys need no release.
 frame(1);frame(0);if(dut.voice_modes!=16'h5555)$fatal(1,"local regression");
 send_cmd("4");send_cmd("4");if(dut.selected!=1)$fatal(1,"repeated selection");
 if(dut.held_audio!=0)$fatal(1,"Bluetooth fabricated pressure input");
 $display("PASS Bluetooth full top: octave/chord/effects cross audio CDC, FFT guards, visual selection, rhythm controls, local coexistence, no autoplay");$finish;
end
initial begin #15000000;$fatal(1,"timeout");end
endmodule

