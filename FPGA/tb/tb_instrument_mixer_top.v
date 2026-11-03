`timescale 1ns/1ps
module tb_instrument_mixer_top;
 reg clk=0;always #10 clk=~clk;
 reg op=0,nxt=0,prev=0,inc=0;reg[32:0]guitar_config;
 pressure_poly8_top dut(.clk_50m(clk),.encoder_a(1'b1),.encoder_b(1'b1),.volume_a(1'b1),.volume_b(1'b1),.game_button_n(1'b1),.fx_button_n(1'b1),.pluck_ir(1'b1),.bt_rx(1'b1),.ttp_sdo(1'b1));
 task tick;begin repeat(4)@(negedge clk);end endtask
 task up;begin inc=1;@(negedge clk);inc=0;tick();end endtask
 task next_item;begin nxt=1;@(negedge clk);nxt=0;tick();end endtask
 task previous_item;begin prev=1;@(negedge clk);prev=0;tick();end endtask
 task check_cross;input[1:0]expected;begin
 repeat(2000)@(negedge clk);
 if(dut.instrument_mode!=expected || dut.mixer_instrument!=expected || dut.dashboard.mixer_data[57:56]!=expected)$fatal(1,"instrument/display identity mismatch");
 if(dut.mixer_frame!==dut.mixer_config)$fatal(1,"audio config CDC mismatch");
 if(dut.underruns!=0)$fatal(1,"audio underrun");
 end endtask
 initial begin
 force dut.enc_inc=inc;force dut.enc_dec=0;force dut.mixer_open=op;force dut.select_short=nxt;force dut.select_long=prev;
 force dut.dashboard.frame_start=1;force dut.dashboard.x=0;force dut.dashboard.y=0;
 wait(dut.audio_rst_n);tick();op=1;@(negedge clk);op=0;tick();
 if(!dut.mixer_active || dut.mixer_item!=15)$fatal(1,"selector not active");
 up();check_cross(1);next_item();up();next_item();up();tick();guitar_config=dut.mixer_config;
 if(guitar_config[13:12]!=1 || !dut.mixer_enable[0])$fatal(1,"guitar hall not set");
 previous_item();previous_item();up();check_cross(2);
 if(dut.mixer_config===guitar_config || dut.mixer_enable[0])$fatal(1,"guitar settings leaked into piano");
 up();check_cross(0);up();check_cross(1);
 if(dut.mixer_config!==guitar_config || !dut.mixer_enable[0])$fatal(1,"guitar settings not restored");
 $display("PASS production top instrument selector -> per-instrument FX -> audio and video CDC; guitar Hall retained, piano/harmonica isolated, no underrun");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
