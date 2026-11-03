`timescale 1ns/1ps
module tb_bluetooth_top;
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
 send_cmd("1");if(dut.voice_modes!=16'h5555 || dut.audio_config[15:0]!=16'h5555)$fatal(1,"remote octave CDC");
 send_cmd("3");if(dut.voice_modes!=16'haaaa)$fatal(1,"remote high");
 send_cmd("6");if(!dut.chord_mode || !dut.audio_config[21])$fatal(1,"remote chord");
 send_cmd("A");send_cmd("B");send_cmd("C");send_cmd("D");
 if(dut.expression_config!=15 || dut.audio_config[58:55]!=15)$fatal(1,"remote effects CDC");
 send_cmd("W");if(dut.visual_mode!=0 || dut.visual_auto)$fatal(1,"wave");
 send_cmd("S");if(dut.visual_mode!=1)$fatal(1,"spectrum");send_cmd("X");if(dut.visual_mode!=2)$fatal(1,"XY");
 send_cmd("R");if(!dut.visual_auto)$fatal(1,"rotation");
 send_cmd("5");if(!dut.test_mode || !dut.test32)$fatal(1,"FFT32");
 send_cmd("T");if(dut.trainer_active)$fatal(1,"FFT trainer blocked");
 send_cmd("8");if(dut.test_mode||dut.expression_config||dut.chord_mode)$fatal(1,"safe reset");
 send_cmd("T");if(!dut.trainer_active || dut.audio_config!=0)$fatal(1,"trainer entry");
 send_cmd("2");send_cmd("3");send_cmd("4");
 if(dut.trainer_song!=1 || dut.trainer_tempo!=2 || !dut.trainer_wait)$fatal(1,"lesson settings");
 send_cmd("5");if(!dut.trainer_running || dut.test_mode || dut.trainer_count!=4)$fatal(1,"lesson start");
 send_cmd("2");if(dut.trainer_song!=1)$fatal(1,"running song guard");
 send_cmd("5");if(dut.trainer_running)$fatal(1,"pause");
 send_cmd("6");if(dut.trainer_count || dut.trainer_step || dut.trainer_running)$fatal(1,"restart");
 send_cmd("8");if(dut.trainer_active || dut.selected!=8)$fatal(1,"lesson exit");
 // Local touch remains usable after Bluetooth; repeated remote keys need no release.
 frame(1);frame(0);if(dut.voice_modes!=16'h5555)$fatal(1,"local regression");
 send_cmd("4");send_cmd("4");if(dut.selected!=1)$fatal(1,"repeated selection");
 if(dut.held_audio!=0)$fatal(1,"Bluetooth fabricated pressure input");
 $display("PASS Bluetooth full top: octave/chord/effects cross audio CDC, FFT guards, visual selection, offline lesson controls, local coexistence, no autoplay");$finish;
end
initial begin #15000000;$fatal(1,"timeout");end
endmodule
