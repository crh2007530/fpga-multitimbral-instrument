`timescale 1ns/1ps
module tb_exp4_oled_bus;
reg clk=0;always #5 clk=~clk;reg rst=0,lesson=1;tri1 scl,sda;
reg[319:0]shape;integer k;
oled_status #(.EXTENDED(1),.EXPANSION(1),.EXPRESSION(1),.WAVEFORM(1),.TRAINER(1),.POWERUP_MS(1),.HALF_CYCLES(4)) dut(
 .clk(clk),.rst_n(rst),.scl(scl),.sda(sda),.trainer_status({39'd0,lesson}),.trainer_target(8'h15),.trainer_next(8'h2a),
 .visual_mode(2'd0),.spectrum_bars(75'd0),.wave_points(shape),.expression_config(4'd0),.octave(2'd0),.keys(11'd0),
 .history(112'd0),.history_valid(4'd0),.event_count(16'd0),.voice_modes(16'd0),.selected(4'd8),.test_mask(4'd0),
 .test_mode(1'b0),.chord_mode(1'b0),.test32(1'b0),.selected_test(5'd0),.mask32(32'd0));
// OLED model only acknowledges; transmitted SDA bits are decoded independently.
assign sda=(dut.u_bus.state==5 || dut.u_bus.state==6)?1'b0:1'bz;
integer pixels=0,wirebytes=0,nbits=0,x,y,b;reg[7:0]expected,serialword;reg[39:0]g;
reg[7:0] pendingbyte;
always @(posedge clk)if(rst && dut.request && dut.operation==1)begin
 pendingbyte=dut.tx_data;
 if(dut.segment==2 && dut.byte_index>=2)begin
  x=dut.byte_index-2;y=dut.page;
  if(lesson || y<4)begin
   g=dut.font(dut.text_char(y,x/6,dut.frame_octave,dut.frame_keys,dut.frame_history,dut.frame_history_valid,dut.frame_event_count));
   expected=x%6<5 ? (g>>(8*(x%6))) : 0;
  end else begin
   expected=0;
   for(b=0;b<8;b=b+1)begin
    if(((y-4)*8+b>=shape[(x/2)*5+:5] && (y-4)*8+b<=shape[(x/2==0?0:x/2-1)*5+:5]) ||
       ((y-4)*8+b<=shape[(x/2)*5+:5] && (y-4)*8+b>=shape[(x/2==0?0:x/2-1)*5+:5]))expected[b]=1;
    if((y-4)*8+b==16 && x%8==0)expected[b]=1;
   end
  end
  if(dut.tx_data!==expected)$fatal(1,"pipelined byte lesson=%d page=%d x=%d got=%h expected=%h",lesson,y,x,dut.tx_data,expected);
  pixels=pixels+1;
 end
end
always @(posedge scl)if(rst && dut.u_bus.state==4)begin
 serialword={serialword[6:0],sda};nbits=nbits+1;
 if(nbits==8)begin
  if(serialword!==pendingbyte)$fatal(1,"physical SDA byte mismatch");
  nbits=0;wirebytes=wirebytes+1;
 end
end
initial begin
 for(k=0;k<64;k=k+1)shape[k*5+:5]=k%32;
 repeat(3)@(negedge clk);rst=1;
 wait(dut.screen_available);@(negedge clk);
 if(pixels!=1024 || wirebytes<1024)$fatal(1,"lesson frame incomplete");
 rst=0;lesson=0;pixels=0;wirebytes=0;nbits=0;repeat(3)@(negedge clk);rst=1;
 wait(dut.screen_available);@(negedge clk);
 if(pixels!=1024 || wirebytes<1024)$fatal(1,"wave frame incomplete");
 $display("PASS OLED pipeline through real I2C: two complete 1024-pixel-byte frames, lesson text and waveform, address/control/serial bytes intact, no off-by-one columns");$finish;
end
initial begin #5000000;$fatal(1,"timeout");end
endmodule

