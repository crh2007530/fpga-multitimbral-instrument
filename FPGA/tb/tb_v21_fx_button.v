`timescale 1ns/1ps
module tb_v21_fx_button;
reg clk=0;always #10 clk=~clk;
reg fxkey=0,gamekey=1;
pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),
 .volume_a(1'b1),.volume_b(1'b1),.game_button_n(gamekey),.fx_button_n(fxkey),
 .pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
defparam dut.fx_button.BUTTON_CYCLES=8;
defparam dut.panel.BUTTON_CYCLES=8;
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task press;begin fxkey=0;ticks(30);fxkey=1;ticks(1500);end endtask
initial begin
 wait(dut.audio_rst_n);ticks(50);
 if(dut.fx_bypass)$fatal(1,"held at boot toggled bypass");
 fxkey=1;ticks(30);
 force dut.expression_bits=4'b1110;force dut.extra_fx=2'b11;ticks(1500);
 if(dut.voice.extra_fx!=3 || !dut.voice.expression_config[3])$fatal(1,"effects setup");
 // Short bouncing pulses cannot activate the switch.
 repeat(3)begin fxkey=0;ticks(2);fxkey=1;ticks(2);end
 ticks(30);if(dut.fx_bypass)$fatal(1,"bounce");
 fxkey=0;ticks(1500);
 if(!dut.fx_bypass || !dut.fx_bypass_frame || dut.voice.extra_fx!=0 || dut.voice.expression_config[3])$fatal(1,"physical bypass to audio");
 if(dut.expression_bits!=14 || dut.extra_fx!=3)$fatal(1,"settings overwritten");
 if(!dut.game_data[117] || dut.game_data[118] || dut.game_data[119] || dut.game_data[124])$fatal(1,"HUD actual FX mismatch");
 if(!dut.game_data[123] || !dut.game_data[122])$fatal(1,"pitch expression was bypassed");
 if(dut.volume_frame!=16 || dut.trainer_active)$fatal(1,"other controls affected");
 ticks(1500);if(!dut.fx_bypass)$fatal(1,"hold retrigger");
 // Adjust settings while dry; re-enable the newest settings, not an old snapshot.
 force dut.extra_fx=2'b01;fxkey=1;ticks(30);press();
 if(dut.fx_bypass || dut.voice.extra_fx!=1 || !dut.voice.expression_config[3])$fatal(1,"restore newest settings");
 force dut.test_mode=1'b1;press();if(dut.fx_bypass)$fatal(1,"test changed bypass");release dut.test_mode;
 gamekey=0;fxkey=0;ticks(1500);gamekey=1;fxkey=1;ticks(30);
 if(!dut.fx_bypass || !dut.trainer_active || !dut.trainer_running)$fatal(1,"independent simultaneous buttons");
 $display("PASS physical FX button: boot guard, bounce, hold, dry/wet, settings preserved/updated, pitch intact, HUD, test isolation, simultaneous game control");$finish;
end
initial begin #5000000;$fatal(1,"timeout");end
endmodule
