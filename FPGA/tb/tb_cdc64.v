`timescale 1ns/1ps
module tb_cdc64;
reg clk=0;always #10 clk=~clk;
tri1 a,b,c,d,e,f,g;pressure_poly8_top dut(.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),.adc1_scl(c),.adc1_sda(d),.apds_sda(e),.oled_sda(f),.ttp_sdo(1'b1));
reg[5:0]ge=0;initial force dut.gesture_events=ge;
reg[7:0]keys=0;reg valid=0;
initial begin force dut.touch_keys=keys;force dut.touch_valid=valid;end
task frame;input[7:0]k;begin @(negedge clk);keys=k;valid=1;@(negedge clk);valid=0;end endtask
task key;input[7:0]k;begin frame(0);frame(0);frame(k);frame(k);repeat(2000)@(negedge clk);end endtask
initial begin wait(dut.audio_rst_n);repeat(1000)@(negedge clk);
 ge=15;@(negedge clk);ge=0;repeat(2000)@(negedge clk);
 if(dut.expression_config!==15 || dut.audio_config[90:87]!==15)$fatal(1,"expression CDC");
 key(32);key(16);
 if(!dut.audio_config[22]||!dut.audio_config[21]||!dut.audio_config[20]||dut.audio_config[86:23]!==64'hffffffffffffffff)$fatal(1,"expanded mailbox");
 key(32);if(dut.audio_config[86:23]!==64'hfffffffffffffffe)$fatal(1,"mask CDC");
 key(128);if(dut.audio_config[90:87]!==0)$fatal(1,"expression safe return");
 if(dut.audio_config[22:20]!==0||dut.selected!=8)$fatal(1,"safe exit CDC");
 $display("PASS top expansion controls, atomic 91-bit CDC including expression config, mask mute and basic return");$finish;end
initial begin #4000000;$fatal(1,"timeout");end
endmodule
