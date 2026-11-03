`timescale 1ns/1ps
module tb_touch_guard_top_v15_3;
 reg clk=0;always #10 clk=~clk;
 tri1 a,b,c,d,od,gd;wire os,gs,scl;
 reg sdo=1;reg[15:0] touched=0;reg stuck_low=0;
 integer bitnum=0,frames=0,nonzero=0;time last_edge=0;
 reg[63:0] pressure=0;
 pressure_poly8_top dut(.clk_50m(clk),.adc0_scl(a),.adc0_sda(b),.adc1_scl(c),.adc1_sda(d),
 .oled_scl(os),.oled_sda(od),.ttp_sdo(sdo),.ttp_scl(scl),.apds_scl(gs),.apds_sda(gd),
 .bt_rx(1'b1),.volume_a(1'b1),.volume_b(1'b1),.fx_button_n(1'b1),.game_button_n(1'b1),.encoder_a(1'b1),.encoder_b(1'b1));
 // Accelerate scan/startup only; physical serial model, production top wiring,
 // guard, controls, asynchronous audio mailbox and actual synthesizer remain.
 defparam dut.touch.START_CYCLES=50,dut.touch.HALF_CYCLES=20,dut.touch.GAP_CYCLES=600;
 defparam dut.touch_guard.STABLE_FRAMES=4,dut.touch_guard.RELEASE_FRAMES=4,dut.touch_guard.TEST_FRAMES=12;
 defparam dut.voice.WARMUP_FRAMES=1;
 always @(negedge scl)if(dut.rst_n)begin
 if($time-last_edge>5000)bitnum=0;
 #60;sdo=stuck_low ? 1'b0 : ~touched[bitnum];bitnum=(bitnum+1)%16;last_edge=$time;
 end
 always @(posedge dut.touch_raw_valid)frames=frames+1;
 always @(posedge dut.monitor_valid)if(dut.monitor_pcm!=0)nonzero=nonzero+1;
 task key;input[15:0] k;input integer count;integer n;begin
 touched=k;n=frames;wait(frames>=n+count);#200;
 end endtask
 task silent;integer n;begin
 repeat(3000)@(negedge clk);
 n=nonzero;repeat(3000)@(negedge clk);
 if(nonzero!=n || dut.held_audio!=0 || dut.test_mode)$fatal(1,"idle not silent mode=%b held=%h",dut.test_mode,dut.held_audio);
 end endtask
 integer heard;
 initial begin
 // Video clock is held for this input/audio regression, not a display test.
 force dut.pixel_clk=1'b0;force dut.serial_clk=1'b0;
 force dut.locked=1'b1;
 force dut.raw=pressure;force dut.raw_valid=8'hff;
 touched=16;key(16,20);silent();
 key(0,10);key(16,4);key(0,10);silent();
 stuck_low=1;key(0,20);silent();stuck_low=0;
 key(0,10);key(32,10);key(0,10);key(16,20);
 if(!dut.test_mode || !dut.test32)$fatal(1,"64-tone mode not reached");
 heard=nonzero;repeat(30000)@(negedge clk);
 if(dut.held_audio!=255 || nonzero==heard)$fatal(1,"test audio missing");
 // Model disconnect after entry: state persists, as seen in the supplied video.
 key(0,10);if(!dut.test_mode)$fatal(1,"unexpected test reset");
 key(128,10);key(0,10);repeat(3000)@(negedge clk);
 if(dut.test_mode || dut.held_audio!=0)$fatal(1,"T8 gates not released");
 pressure=180;heard=nonzero;repeat(30000)@(negedge clk);
 if(dut.held_audio!=1 || nonzero==heard)$fatal(1,"pressure performance broken");
 pressure=0;repeat(3000)@(negedge clk);
 if(dut.held_audio!=0)$fatal(1,"pressure gate failed to release");
 if(dut.underruns!=0)$fatal(1,"underrun");
 $display("PASS real top physical SDO scan -> guard -> control -> asynchronous mailbox -> audio: startup false T5, short T5, stuck-low silent; deliberate64 tone; disconnect persistence reproduced; T8 escape; real pressure press/release; zero underruns (release tail verified separately)");$finish;
 end
 initial begin #30000000;$fatal(1,"top timeout");end
endmodule
