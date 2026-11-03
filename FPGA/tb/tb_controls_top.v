`timescale 1ns/1ps
module tb_controls_top;
reg clk=0;always #10 clk=~clk;
tri1 a,b,c,d,os,od,gs,gd;
reg [7:0] keys=0;reg valid=0;
pressure_poly8_top dut(.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),.adc1_scl(c),.adc1_sda(d),.oled_scl(os),.oled_sda(od),.ttp_sdo(1'b1),.apds_scl(gs),.apds_sda(gd));
task frame;input [7:0] k;begin @(negedge clk);keys=k;valid=1;@(negedge clk);valid=0;end endtask
task key;input [7:0] k;begin frame(0);frame(0);frame(k);frame(k);repeat(2400)@(negedge clk);end endtask
initial begin
 force dut.touch_keys=keys;force dut.touch_valid=valid;
 force dut.raw=64'h6060606060606060;force dut.raw_valid=255;
 #2000000;
 key(8);key(4);
 if(dut.voice.notes[0].runtime_inc!==32'd93548082||dut.voice.notes[1].runtime_inc!==32'd52502086)$fatal(1,"independent pitch CDC");
 if(dut.logger.voice_modes!==16'd2||dut.display_status.voice_modes!==16'd2||dut.selected!==0)$fatal(1,"UI metadata");
 key(16);if(dut.held_audio!==15||!dut.voice.test_mode)$fatal(1,"FFT CDC/gates");
 key(32);if(dut.held_audio!==14)$fatal(1,"test mute CDC");
 key(128);if(dut.held_audio!==255||dut.voice.voice_modes!==0||dut.voice.test_mode)$fatal(1,"return physical pressure");
 if(dut.display_status.text_char(0,0,0,0,112'd0,0,0)!="P")$fatal(1,"OLED PLAY");
 if(dut.display_status.text_char(0,0,0,0,112'h1000000,0,0)!="F")$fatal(1,"OLED FFT");
 if(dut.display_status.text_char(2,0,0,0,112'd0,0,0)!="W")$fatal(1,"OLED waveform page");
 $display("PASS real top controls: atomic frame-scheduled 59-bit mailbox, per-voice increments, FFT gates/mute/exit, UART/OLED metadata, OLED mode/waveform labels");$finish;
end
initial begin #4000000;$fatal(1,"timeout");end
endmodule
