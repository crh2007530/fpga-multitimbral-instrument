`timescale 1ns/1ps
module tb_exp4_top;
reg clk=0;always #10 clk=~clk;tri1 a,b,c,d,e,f;
pressure_poly8_top #(.TRAINER_CLOCK_HZ(240)) dut(.volume_a(1'b1),.volume_b(1'b1),.fx_button_n(1'b1),.game_button_n(1'b1),.encoder_a(1'b1),.encoder_b(1'b1),.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),.adc1_scl(c),.adc1_sda(d),.apds_sda(e),.oled_sda(f),.ttp_sdo(1'b1));
reg[7:0]keys=0;reg fv=0;reg[5:0]ge=0;
initial begin force dut.touch_keys=keys;force dut.touch_valid=fv;force dut.gesture_events=ge;force dut.audio_raw=0;force dut.audio_valid=255;end
task frame;input[7:0]k;begin @(negedge clk);keys=k;fv=1;repeat(4)@(negedge clk);fv=0;repeat(3)@(negedge clk);end endtask
task key;input[7:0]k;begin frame(0);frame(k);frame(0);end endtask
initial begin
 wait(dut.audio_rst_n);repeat(2000)@(negedge clk);
 key(32);ge=15;@(negedge clk);ge=0;repeat(2000)@(negedge clk);
 if(!dut.chord_mode||dut.expression_config!=15)$fatal(1,"precondition");
 frame(64);repeat(250)@(negedge clk);frame(0);repeat(2000)@(negedge clk);
 if(!dut.trainer_active || dut.audio_config!=0)$fatal(1,"training audio isolation");
 if(dut.display_status.live_context[70]!=1 || dut.logger.trainer_flags[0]!=1)$fatal(1,"metadata routing");
 if(dut.logger.expression_config!=0 || dut.logger.chord_mode!=0 || dut.logger.voice_modes!=0)$fatal(1,"effective telemetry");
 key(16);repeat(30)@(negedge clk);
 if(dut.test_mode||!dut.trainer_running)$fatal(1,"training key5 leaked to FFT");
 if(dut.held_audio!=0)$fatal(1,"lesson fabricated pressure sound");
 key(128);repeat(2000)@(negedge clk);
 if(dut.trainer_active||dut.test_mode||dut.chord_mode||dut.expression_config!=0||dut.selected!=8)$fatal(1,"safe return");
 $display("PASS full top: long7 entry, frame-atomic lesson audio config, OLED/UART integration, training keys isolated from FFT, no autoplay, key8 resets safely");$finish;
end
initial begin #5000000;$fatal(1,"timeout");end
endmodule
