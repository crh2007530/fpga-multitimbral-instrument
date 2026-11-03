`timescale 1ns/1ps
module tb_v21_panel_top;
reg clk=0;always #10 clk=~clk;reg a=1,b=1,key=1;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),
 .volume_a(a),.volume_b(b),.fx_button_n(1'b1),.game_button_n(key),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
defparam dut.panel.FILTER_CYCLES=3;
defparam dut.panel.BUTTON_CYCLES=8;
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task press;begin key=0;ticks(30);key=1;ticks(30);end endtask
initial begin
 wait(dut.audio_rst_n);ticks(40);
 if(dut.volume_level!=16 || dut.game_data[116:110]!=100)$fatal(1,"default volume/HUD");
 {a,b}=1;ticks(15);{a,b}=0;ticks(15);{a,b}=2;ticks(15);{a,b}=3;ticks(15);
 ticks(1500);
 if(dut.volume_level!=15 || dut.game_data[116:110]!=94 || dut.volume_frame!=15)$fatal(1,"physical rotary through audio CDC and HUD");
 if(dut.instrument_mode!=0)$fatal(1,"volume changed timbre");
 press();if(!dut.trainer_active || !dut.trainer_running)$fatal(1,"physical enter/start");
 press();if(!dut.trainer_active || dut.trainer_running)$fatal(1,"physical pause");
 press();if(!dut.trainer_running)$fatal(1,"physical resume");
 if(dut.test_mode)$fatal(1,"unexpected test audio");
 $display("PASS actual V21 top: new pins -> debounce -> game, new rotary -> volume mailbox/frame latch + HUD, timbre preserved");$finish;
end
initial begin #5000000;$fatal(1,"timeout");end
endmodule

