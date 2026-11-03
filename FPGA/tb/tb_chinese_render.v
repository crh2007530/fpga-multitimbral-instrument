`timescale 1ns/1ps
module tb_chinese_render;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg[127:0]state=0;reg[10:0]x=0;reg[9:0]y=0;
wire[23:0]rgb;wire de;reg valid=0;
video_labels dut(state,clk,rst,x,y,1'b0,1'b0,valid,24'h091120,,,de,rgb,1'b0,22'd0,64'd0,9'd0,1'b0,24'd0);
integer f,i,j,mode,lit;reg[255:0]name;
initial begin
repeat(4)@(negedge clk);rst=1;
// Verify high CJK IDs are not truncated to ASCII and all normal modes select the correct row.
x=128;y=16;#1;if(dut.letter!=dut.T0[511:504])$fatal(1,"normal title");
state[120]=1;x=128+5*32;#1;if(dut.letter!=dut.T0P[(63-5)*8+:8])$fatal(1,"piano title");
state[120]=0;state[121]=1;#1;if(dut.letter!=dut.T0F[(63-5)*8+:8])$fatal(1,"flute title");
state[127]=1;#1;if(dut.letter!=dut.T04[(63-5)*8+:8])$fatal(1,"test priority");
state[126]=1;#1;if(dut.letter!=dut.T064[(63-5)*8+:8])$fatal(1,"test64 priority");
for(mode=0;mode<3;mode=mode+1)begin
 state=0;valid=0;
 case(mode)
 0:begin name="checks/chinese_play.ppm";state[124:122]=7;state[119:118]=3;end
 1:begin name="checks/chinese_game.ppm";state[30]=1;state[100]=1;state[118]=1;state[123]=1;state[120]=1;state[51:36]=12345;state[59:52]=12;state[67:60]=25;state[75:68]=32;end
 2:begin name="checks/chinese_test.ppm";state[127]=1;state[126]=1;end
 endcase
 repeat(160)@(negedge clk);
 f=$fopen(name,"wb");$fwrite(f,"P6\n1280 720\n255\n");lit=0;
 for(i=0;i<1280*720+4;i=i+1)begin
  @(negedge clk);valid=i<1280*720;x=i%1280;y=i/1280;
  @(posedge clk);#1;
  if(i>=3 && i<1280*720+3)begin
   if(^rgb===1'bx)$fatal(1,"unknown CJK pixel");
   $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
   if(rgb==24'he1edf7)lit=lit+1;
  end
 end
 $fclose(f);if(lit<1000)$fatal(1,"blank Chinese screen");
end
$display("PASS Chinese mode titles and full raster PLAY/game paused/TEST rendering, no unknown glyph pixels");$finish;
end
endmodule
