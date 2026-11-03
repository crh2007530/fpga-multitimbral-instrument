`timescale 1ns/1ps
module tb_exp4_oled;
reg clk=0;always #5 clk=~clk;tri1 sda;reg rst=0;reg[39:0]st=0;
oled_status #(.EXTENDED(1),.EXPANSION(1),.EXPRESSION(1),.WAVEFORM(1),.TRAINER(1)) dut(
 .clk(clk),.rst_n(rst),.sda(sda),.trainer_status(st),.trainer_target(8'h15),.trainer_next(8'h2a),
 .visual_mode(2'd0),.expression_config(4'd0),.mask32(32'd0),.selected_test(5'd0),.test32(1'b0),
 .chord_mode(1'b0),.test_mode(1'b0),.test_mask(4'd0),.selected(4'd8),.voice_modes(16'd0));
reg[127:0]ctx;reg[167:0]line;integer row,col,x,fd;
initial begin
 #10;rst=1;force dut.state=4;
 st[0]=1;st[1]=1;st[5:4]=1;st[7:6]=1;st[12:8]=4;st[15:13]=3;
 st[23:16]=12;st[31:24]=3;st[39:32]=2;#2;ctx=dut.live_context;
 for(row=0;row<8;row=row+1)begin
  for(col=0;col<21;col=col+1)line[167-col*8-:8]=dut.text_char(row,col,0,0,ctx,0,0);
  $display("%s",line);
  case(row)
   0:if(line!=="OFFLINE S2 CHORDS    ")$fatal(1,"song");
   1:if(line!=="RUN   BPM:090 RHYTHM ")$fatal(1,"tempo/mode");
   2:if(line!=="STEP:05/16 COUNT:3   ")$fatal(1,"step/count");
   3:if(line!=="NOW: 1-3-5---        ")$fatal(1,"target");
   4:if(line!=="NEXT:-2-4-6--        ")$fatal(1,"preview");
   5:if(line!=="OK:012 MISS:003      ")$fatal(1,"score");
   6:if(line!=="WRONG:002 5:PLAY     ")$fatal(1,"wrong");
  endcase
 end
 force dut.frame_history=ctx;fd=$fopen("checks/trainer_oled.hex","w");
 for(row=0;row<8;row=row+1)for(x=0;x<128;x=x+1)begin
  force dut.page=row;force dut.byte_index=x+2;force dut.character_index=x/6;force dut.glyph_column=x%6;repeat(4)@(negedge clk);#1;
  $fdisplay(fd,"%02x",dut.pixels);
 end
 $fclose(fd);$display("PASS complete teaching OLED labels, mask/score decimal decoding, real font raster export");$finish;
end
endmodule
