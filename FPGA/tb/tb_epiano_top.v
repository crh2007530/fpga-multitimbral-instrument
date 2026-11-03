`timescale 1ns/1ps
module tb_epiano_top;
 reg clk=0;always #10 clk=~clk;
 tri1 a,b,c,d,od,gd;wire os,gs,scl;
 reg rx=1,ea=1,eb=1;reg sdo=1;reg[15:0] touched=0;
 integer bitnum=0,frames=0;time last_edge=0;
 pressure_poly8_top #(.TRAINER_CLOCK_HZ(50000),.BT_CLOCK_HZ(320000),.BT_BAUD(10000)) dut(.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),.adc1_scl(c),.adc1_sda(d),
 .oled_scl(os),.oled_sda(od),.ttp_sdo(sdo),.ttp_scl(scl),.apds_scl(gs),.apds_sda(gd),
 .bt_rx(rx),.volume_a(1'b1),.volume_b(1'b1),.fx_button_n(1'b1),.game_button_n(1'b1),.encoder_a(ea),.encoder_b(eb));
 defparam dut.touch.START_CYCLES=50,dut.touch.HALF_CYCLES=20,dut.touch.GAP_CYCLES=600;
 defparam dut.voice.WARMUP_FRAMES=1;
 defparam dut.encoder.FILTER_CYCLES=3;
 always @(negedge scl)if(dut.rst_n)begin
 if($time-last_edge>5000)bitnum=0;
 #60;sdo=~touched[bitnum];bitnum=(bitnum+1)%16;last_edge=$time;
 end
 always @(posedge dut.touch_raw_valid)frames=frames+1;
 task ab;input[1:0]v;begin @(negedge clk);{ea,eb}=v;repeat(12)@(negedge clk);end endtask
 task rotate;begin ab(2);ab(0);ab(1);ab(3);end endtask
 task uart_byte;input[7:0]v;integer j;begin
 @(negedge clk);rx=0;repeat(32)@(negedge clk);
 for(j=0;j<8;j=j+1)begin rx=v[j];repeat(32)@(negedge clk);end
 rx=1;repeat(32)@(negedge clk);end endtask
 task key;input[15:0] k;input integer count;integer n;begin
 touched=k;n=frames;wait(frames>=n+count);#200;
 end endtask
 task noisy_hold;input[15:0] k;integer j;begin key(k,2);key(1,1);key(k,10);for(j=0;j<6;j=j+1)begin key(1,1);key(k,8);key(0,1);key(k,8);end end endtask
 task press;input[15:0] k;begin key(0,12);key(k,12);key(0,12);end endtask
 initial begin
 // Focus on physical input/control integration, not raster/analog PLL.
 force dut.pixel_clk=1'b0;force dut.serial_clk=1'b0;force dut.locked=1'b1;
 force dut.raw=64'd0;force dut.raw_valid=8'hff;
 // Worst-case Bluetooth busy: physical inputs must still work in the real top.
 force dut.bt_control_lock=1'b1;
 key(0,12);
 rotate;rotate;repeat(2000)@(negedge clk);
 if(dut.instrument_mode!=2 || !dut.audio_config[91] || !dut.game_data[120])$fatal(1,"encoder/piano CDC/HUD");
 uart_byte("@");uart_byte("A");uart_byte(10);repeat(800)@(negedge clk);
 if(dut.instrument_mode!=0)$fatal(1,"legacy Bluetooth timbre cycle");
 rotate;rotate;repeat(2000)@(negedge clk);
 if(dut.instrument_mode!=2 || !dut.audio_config[91])$fatal(1,"reselect piano");
 press(1);
 // No release: confirmed T4 -> conflicting frames -> stable T2 must recover.
 key(8,12);key(3,4);key(2,12);
 if(dut.voice_modes[1:0]!=0)$fatal(1,"rollover still locked");
 key(0,12);press(1);
 if(dut.voice_modes!=16'h5555)$fatal(1,"PLAY touch blocked by Bluetooth busy");
 noisy_hold(64);key(0,12);
 if(!dut.trainer_active || dut.trainer_running)$fatal(1,"local T7 entry");
 noisy_hold(16);key(0,12);if(!dut.trainer_running)$fatal(1,"local T5 start blocked");
 key(0,30);if(!dut.trainer_running)$fatal(1,"autopause");
 press(16);if(dut.trainer_running)$fatal(1,"local T5 pause");
 noisy_hold(16);key(0,12);if(!dut.trainer_running)$fatal(1,"local T5 resume");
 press(128);if(dut.trainer_active)$fatal(1,"local T8 exit blocked");
 noisy_hold(64);key(0,12);press(16);press(16);
 if(!dut.trainer_active || dut.trainer_running)$fatal(1,"pause setup");
 press(128);if(dut.trainer_active)$fatal(1,"T8 exit from paused");
 release dut.bt_control_lock;
 if(dut.held_audio!=0 || dut.test_mode)$fatal(1,"unintended audio test");
 $display("PASS E.PIANO physical encoder, legacy UART, audio CDC and HUD; real top noisy physical SDO: wrong-key and zero frames per hold, with Bluetooth busy held high: PLAY keys, T7 enter, T5 start/pause/resume, T8 exit running/paused, no unintended test audio");$finish;
 end
 initial begin #30000000;$fatal(1,"timeout");end
endmodule



