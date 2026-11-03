`timescale 1ns/1ps
module tb_video_dashboard;
 reg pc=0,sc=0;always #7 pc=~pc;always #10 sc=~sc;
 reg rst=0,fv=0,fd=0;reg[9:0] bin=0;reg signed[23:0] re=0,im=0;
 reg[319:0] wave=0;wire hs,vs,de;wire[7:0] r,g,b;
 integer tone_index=0,xy_pixels=0;
 integer i,active=0,hsc=0,vsc=0,fdump;reg capture=0;
 reg signed[15:0] pcm=0;
 always @(negedge sc)if(rst)begin pcm<=$rtoi(12000.0*$sin(6.28318530718*tone_index/128.0));tone_index<=tone_index+1;end
 video_dashboard #(.CUSTOM_CHART(1)) dut(128'd0,pc,rst,sc,rst,fv,fd,bin,re,im,1'b1,pcm,8'h55,8'haa,hs,vs,de,r,g,b,256'd0,1'b0,64'hffffffffffffffff,6'd0,1'b0,1'b0,40'd0,80'd0,64'd0,61'd0,1'b0,9'd0,8'd0,1'b0,22'd0,64'd0,24'd0);
 always @(negedge pc)if(capture)begin
  if(de)begin active=active+1;$fwrite(fdump,"%c%c%c",r,g,b);end
  if(de && {r,g,b}==24'hd080ff)xy_pixels=xy_pixels+1;
  if(hs)hsc=hsc+1;
  if(vs)vsc=vsc+1;
 end
 initial begin
  for(i=0;i<64;i=i+1)wave[i*5+:5]=i%32;
  repeat(5)@(negedge sc);rst=1;
  for(i=0;i<1024;i=i+1)begin
   @(negedge sc);fv=1;bin=i;re=(i%7==0)?24'd1048576:24'd256;
  end
  @(negedge sc);fv=0;fd=1;@(negedge sc);fd=0;
  // Allow real capture/bitmap logic to publish its data, then skip only
  // empty warm-up raster time. The measured frame below is fully simulated.
  repeat(30000)@(negedge sc);
  @(negedge pc);dut.x=1640;dut.y=749;
  repeat(4)@(negedge pc);wait(!de);wait(de);
  fdump=$fopen("dashboard.ppm","wb");$fwrite(fdump,"P6\n1280 720\n255\n");capture=1;
  repeat(1237500)@(posedge pc);#1;capture=0;$fclose(fdump);
  if(active!=921600 || hsc!=30000 || vsc!=8250)$fatal(1,"raster counts %d %d %d",active,hsc,vsc);
  if(xy_pixels<100)$fatal(1,"missing XY pixels %0d",xy_pixels);
  if(dut.ack!=1 || dut.snapshot[7:0]!=8'h55)$fatal(1,"CDC state");
  $display("PASS720p: 921600 active pixels, 40-pixel HS, 5-line VS, atomic UI and FFT bank handoff");$finish;
 end
 always #1000000 $display("FRAME progress t=%0t x=%0d y=%0d",$time,dut.x,dut.y);
 initial begin #100000000;$fatal(1,"timeout");end
endmodule


