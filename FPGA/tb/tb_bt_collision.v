`timescale 1ns/1ps
module tb_bt_collision #(parameter integer DECODE_EDGE=0);
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
initial begin
 wait(dut.audio_rst_n);repeat(100)@(negedge clk);
 // First physical FFT-key frame: not accepted until the second identical frame.
 keys=16;fv=1;@(negedge clk);fv=0;
 fork
  begin byte_send("@");byte_send("T");byte_send(10);end
  begin
   if(DECODE_EDGE)wait(dut.bluetooth.valid && dut.bluetooth.data==10);
   else wait(dut.bt_trainer_toggle);
   @(negedge clk);fv=1;
   @(negedge clk);fv=0;keys=0;
  end
 join
 repeat(10)@(negedge clk);
 if(dut.trainer_active && dut.test_mode)$fatal(1,"COLLISION: remote T and local FFT5 entered lesson AND FFT simultaneously");
 if(!dut.trainer_active || dut.test_mode)$fatal(1,"remote priority not honored");
 $display("PASS remote lesson entry excludes simultaneous physical FFT command");$finish;
end
initial begin #5000000;$fatal(1,"timeout");end
endmodule

module tb_bt_collision_decode;
 tb_bt_collision #(.DECODE_EDGE(1)) scenario();
endmodule
