`timescale 1ns/1ps
module tb_exp3_visual;
reg clk=0;always #5 clk=~clk;tri1 sda;reg rst=0;
oled_status #(.EXTENDED(1),.EXPANSION(1),.EXPRESSION(1),.WAVEFORM(1)) dut(
 .clk(clk),.rst_n(rst),.sda(sda));
integer mode,x,y,b,k,fd,expected,xx,yy;real angle;
reg[319:0] points;reg[74:0] bars;reg[127:0]ctx;
reg[167:0] title;
initial begin
 #10;rst=1;force dut.state=4;
 #10;
 for(k=0;k<64;k=k+1)points[k*5+:5]=16+$rtoi(12*$sin(k*6.28318530718/32));
 for(k=0;k<15;k=k+1)bars[k*5+:5]=(k==2)?24:(k==4)?12:0;
 force dut.frame_wave=points;force dut.frame_spectrum=bars;force dut.frame_history=ctx;
 fd=$fopen("checks/oled_raster.hex","w");
 for(mode=0;mode<3;mode=mode+1)begin
  ctx=0;ctx[69:68]=mode;
  for(k=0;k<21;k=k+1)title[167-8*k-:8]=dut.text_char(2,k,0,0,ctx,0,0);
  $display("PAGE %0d title=%s",mode,title);
  for(y=0;y<8;y=y+1)for(x=0;x<128;x=x+1)begin
   force dut.page=y;force dut.byte_index=x+2;
   force dut.character_index=x/6;force dut.glyph_column=x%6;
   repeat(4)@(negedge clk);#1;
   if(y>=4 && mode!=0)begin
    expected=0;
    for(b=0;b<8;b=b+1)begin
     yy=(y-4)*8+b;
     if(mode==1 && x<120 && x%8<6 && yy>=32-bars[(x/8)*5+:5])expected=expected|(1<<b);
     if(mode==2)for(k=0;k<60;k=k+1)
      if(x/4==points[k*5+:5] && yy==points[(k+4)*5+:5])expected=expected|(1<<b);
    end
    if(dut.pixels!==expected[7:0])$fatal(1,"mode%0d x%0d y%0d",mode,x,y);
   end
   $fdisplay(fd,"%02x",dut.pixels);
  end
 end
 $fclose(fd);
 $display("PASS all spectrum and delayed-XY pixels, three complete OLED frame raster exports");$finish;
end
endmodule

