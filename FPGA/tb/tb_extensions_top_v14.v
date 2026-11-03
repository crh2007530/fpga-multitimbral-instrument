`timescale 1ns/1ps
module tb_extensions_top_v14;
 reg clk=0;always #10 clk=~clk;tri1 a,b,c,d,e,f;reg rx=1;wire tx;
 pressure_poly8_top #(.BT_CLOCK_HZ(320000),.BT_BAUD(10000),.TRAINER_CLOCK_HZ(1000),.CLIP_ADDR_BITS(6)) dut(
 .volume_a(1'b1),.volume_b(1'b1),.fx_button_n(1'b1),.game_button_n(1'b1),.encoder_a(1'b1),.encoder_b(1'b1),.clk_50m(clk),.bt_rx(rx),.bt_tx(tx),.adc0_scl(a),.adc0_sda(b),.adc1_scl(c),.adc1_sda(d),.apds_sda(e),.oled_sda(f),.ttp_sdo(1'b1));
 defparam dut.voice.WARMUP_FRAMES=1;
 reg[63:0] raw=0;
 initial begin force dut.touch_keys=0;force dut.touch_valid=0;force dut.gesture_events=0;force dut.audio_raw=raw;force dut.audio_valid=255;end
 wire[7:0] decoded;wire dv,de;integer nr=0;reg[7:0] response[0:99];
 bt_uart_rx #(.CLOCK_HZ(320000),.BAUD(10000)) sink(clk,dut.rst_n,tx,decoded,dv,de);
 always @(posedge clk)if(dv)begin response[nr]=decoded;nr=nr+1;end
 function[7:0] hx;input[3:0] n;begin hx=n<10?48+n:65+n-10;end endfunction
 task byte_send;input[7:0] v;integer j;begin
 @(negedge clk);rx=0;repeat(32)@(negedge clk);for(j=0;j<8;j=j+1)begin rx=v[j];repeat(32)@(negedge clk);end rx=1;repeat(32)@(negedge clk);
 end endtask
 task hexsend;input[7:0] v;begin byte_send(hx(v[7:4]));byte_send(hx(v[3:0]));end endtask
 task send_ext;input[7:0] op,seq;input integer length;input[255:0] payload;integer k;reg[7:0] sum;begin
 nr=0;sum=op+seq+length;byte_send("!");byte_send(op);hexsend(seq);hexsend(length);
 for(k=0;k<length;k=k+1)begin hexsend(payload[k*8+:8]);sum=sum+payload[k*8+:8];end
 hexsend(-sum);byte_send(10);wait(!dut.ext_busy);repeat(400)@(negedge clk);
 if(nr<11 || response[0]!="!" || response[1]!="r" || response[6]!="0" || response[7]!="0" || de)$fatal(1,"UART response error op=%c nr=%d",op,nr);
 end endtask
 task command;input[7:0] c;begin byte_send("@");byte_send(c);byte_send(10);repeat(2000)@(negedge clk);end endtask
 reg[31:0] rom[0:127];integer i,nonzero;reg[255:0] chart;
 initial begin
 $readmemh("assets/midi_inc_128.hex",rom);wait(dut.audio_rst_n);repeat(3000)@(negedge clk);
 send_ext("F",50,1,3);repeat(5000)@(negedge clk);
 if(dut.extra_audio_config!=3)$fatal(1,"FX config CDC");
 send_ext("M",1,8,64'h4545454545454545);repeat(5000)@(negedge clk);
 if(!dut.map_use || dut.voice.batch_pitch.batch.current[0]!=rom[69] || dut.voice.batch_pitch.batch.current[8]!=rom[73] || dut.note_ids[6:0]!=69)$fatal(1,"real UART->CDC->MIDI->audio pitch mismatch");
 if(dut.held_audio!=0)$fatal(1,"map fabricated key press");
 chart={32{8'h81}};send_ext("C",2,32,chart);command("T");
 if(!dut.trainer_active || dut.trainer_target!=8'h81 || dut.joint_lights.guide_target!=8'h81)$fatal(1,"downloaded chart LED disconnected");
 // Skip only raster waiting; check real CDC and renderer pipelined note masks.
 repeat(200)@(negedge clk);@(negedge dut.pixel_clk);dut.dashboard.x=1649;dut.dashboard.y=749;
 repeat(20)@(negedge dut.pixel_clk);
 if(dut.dashboard.snapshot[184]!=1 || dut.dashboard.snapshot[183:144]!={5{8'h81}} || dut.dashboard.game_view.mask3[0]!=8'h81)$fatal(1,"HDMI does not render uploaded chart");
 command("8");raw=180;repeat(15000)@(negedge clk);send_ext("B",3,0,0);
 wait(dut.extensions.clip_ready);nonzero=0;
 for(i=0;i<64;i=i+1)if(dut.extensions.recorder.memory[i]!=128)nonzero=nonzero+1;
 if(nonzero<16 || dut.extensions.clip_count!=64)$fatal(1,"actual synthesis PCM not recorded");
 send_ext("G",4,2,0);if(nr!=75)$fatal(1,"UART recording block length");
 raw=0;repeat(5000)@(negedge clk);send_ext("D",5,0,0);repeat(5000)@(negedge clk);
 if(dut.map_use || dut.chart_enabled || dut.voice.batch_pitch.batch.current[0]!=32'd46774041)$fatal(1,"default map restore");
 if(dut.underruns!=0)$fatal(1,"audio underrun while sending recording");
 $display("PASS real top UART: map -> CDC -> audio targets; chart -> LED + HDMI; actual synthesized PCM capture -> UART return; defaults; zero underruns");$finish;
 end
 initial begin #30000000;$fatal(1,"timeout");end
endmodule
